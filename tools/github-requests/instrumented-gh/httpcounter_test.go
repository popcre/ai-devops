package httpcounter

import (
	"bytes"
	"io"
	"net/http"
	"net/http/httptest"
	"net/http/httptrace"
	"net/url"
	"os"
	"sync"
	"sync/atomic"
	"testing"
)

func TestConcurrentWritesComposeExistingHooks(t *testing.T) {
	var received, originalHooks atomic.Uint64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		received.Add(1)
		w.Write([]byte("fake-private-body"))
	}))
	defer server.Close()
	parsed, _ := url.Parse(server.URL)
	read, write, err := os.Pipe()
	if err != nil {
		t.Fatal("pipe unavailable")
	}
	defer read.Close()
	state.pipe, state.host = write, parsed.Host
	state.active, state.pending, state.writes, state.failed, state.external = 0, 0, 0, 0, 0
	state.finished, state.incomplete = false, false
	client := &http.Client{Transport: Wrap(http.DefaultTransport)}
	var group sync.WaitGroup
	for i := 0; i < 20; i++ {
		group.Add(1)
		go func() {
			defer group.Done()
			request, _ := http.NewRequest("GET", server.URL+"/?secret=fake-private-query", nil)
			request.Header.Set("Authorization", "fake-private-token")
			request = request.WithContext(httptrace.WithClientTrace(request.Context(), &httptrace.ClientTrace{
				WroteRequest: func(httptrace.WroteRequestInfo) { originalHooks.Add(1) },
			}))
			response, err := client.Do(request)
			if err != nil {
				t.Error("fixture request failed")
				return
			}
			io.Copy(io.Discard, response.Body)
			response.Body.Close()
		}()
	}
	group.Wait()
	Finish()
	raw, _ := io.ReadAll(read)
	if received.Load() != 20 || originalHooks.Load() != 20 || state.writes != 20 || state.incomplete {
		t.Fatal("concurrent server/hook/counter mismatch")
	}
	for _, secret := range []string{"fake-private-body", "fake-private-query", "fake-private-token", parsed.Host} {
		if bytes.Contains(raw, []byte(secret)) {
			t.Fatal("private data reached metadata")
		}
	}
}
