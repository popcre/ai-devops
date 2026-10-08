// Package httpcounter observes completed outgoing writes without inspecting data.
// Linux prototype owned by #660. It is not a fleet-total or server billing counter.
package httpcounter

import (
	"encoding/json"
	"net/http"
	"net/http/httptrace"
	"os"
	"strconv"
	"strings"
	"sync"
	"syscall"
)

var state = struct {
	sync.Mutex
	pipe                                      *os.File
	host                                      string
	active, pending, writes, failed, external uint64
	finished, incomplete                      bool
}{}

func init() {
	fdText := os.Getenv("AI_GH_HTTP_COUNTER_FD")
	host := os.Getenv("AI_GH_HTTP_COUNTER_HOST")
	os.Unsetenv("AI_GH_HTTP_COUNTER_FD")
	os.Unsetenv("AI_GH_HTTP_COUNTER_HOST")
	fd, err := strconv.Atoi(fdText)
	if err != nil || fd < 3 || fd > 1024 || host == "" {
		return
	}
	var stat syscall.Stat_t
	if syscall.Fstat(fd, &stat) != nil || stat.Mode&syscall.S_IFMT != syscall.S_IFIFO {
		return
	}
	syscall.CloseOnExec(fd)
	state.pipe = os.NewFile(uintptr(fd), "httpcounter")
	state.host = strings.ToLower(host)
	// Fixed channel records only. No command, error, route or HTTP data.
	if _, err := state.pipe.Write([]byte("{\"schema\":1,\"started\":true}\n")); err != nil {
		state.incomplete = true
	}
}

type transport struct{ next http.RoundTripper }

func Wrap(next http.RoundTripper) http.RoundTripper {
	if state.pipe == nil {
		return next
	}
	return transport{next}
}

func (t transport) RoundTrip(req *http.Request) (*http.Response, error) {
	state.Lock()
	state.active++
	state.Unlock()
	var got, wrote bool // guarded by state's mutex, hooks may be concurrent
	api := strings.EqualFold(req.URL.Host, state.host)
	trace := &httptrace.ClientTrace{
		GotConn: func(httptrace.GotConnInfo) {
			state.Lock()
			got = true
			state.Unlock()
		},
		WroteRequest: func(info httptrace.WroteRequestInfo) {
			state.Lock()
			defer state.Unlock()
			wrote = true
			if state.finished {
				state.incomplete = true
				return
			}
			if info.Err != nil {
				state.failed++
				state.incomplete = true
				return
			}
			if api {
				state.writes++
			} else {
				state.external++
			}
		},
	}
	response, err := t.next.RoundTrip(req.WithContext(httptrace.WithClientTrace(req.Context(), trace)))
	state.Lock()
	state.active--
	// A connection without a write callback can have late hooks. Retain an
	// incomplete marker rather than assuming zero; do not wait or replay.
	if got && !wrote {
		state.pending++
		state.incomplete = true
	}
	state.Unlock()
	return response, err
}

func Finish() {
	state.Lock()
	defer state.Unlock()
	if state.pipe == nil || state.finished {
		return
	}
	state.finished = true
	// Observed subset only; command/client census is not qualified yet.
	record := struct {
		Schema         int     `json:"schema"`
		Finished       bool    `json:"finished"`
		ObservedWrites uint64  `json:"observed_completed_writes"`
		FailedWrites   uint64  `json:"failed_write_attempts"`
		ExternalWrites uint64  `json:"observed_external_writes"`
		Incomplete     bool    `json:"incomplete"`
		HTTPRequests   *uint64 `json:"http_requests"`
	}{1, true, state.writes, state.failed, state.external, state.incomplete || state.active != 0 || state.pending != 0, nil}
	json.NewEncoder(state.pipe).Encode(record)
	state.pipe.Close()
}
