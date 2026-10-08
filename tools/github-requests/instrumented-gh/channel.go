package httpcounter

import (
	"os"
	"strings"
)

func init() {
	fd, handle, host := os.Getenv("AI_GH_HTTP_COUNTER_FD"), os.Getenv("AI_GH_HTTP_COUNTER_HANDLE"), os.Getenv("AI_GH_HTTP_COUNTER_HOST")
	for _, key := range []string{"AI_GH_HTTP_COUNTER_FD", "AI_GH_HTTP_COUNTER_HANDLE", "AI_GH_HTTP_COUNTER_HOST"} {
		os.Unsetenv(key)
	}
	state.pipe = openChannel(fd, handle)
	if state.pipe == nil {
		return
	}
	if host == "" {
		state.pipe.Close()
		state.pipe = nil
		return
	}
	state.host = strings.ToLower(host)
	if _, err := state.pipe.Write([]byte("{\"schema\":1,\"started\":true}\n")); err != nil {
		state.incomplete = true
	}
}
