//go:build windows

package httpcounter

import (
	"bytes"
	"context"
	"encoding/hex"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"testing"
	"time"

	"golang.org/x/sys/windows"
)

var measured = struct {
	sync.Mutex
	coldBase, coldCandidate, warmBase, warmCandidate []int64
}{}

// Numeric receipt only. File paths and diagnostics never enter this schema.
type numericReceipt struct {
	Schema            int        `json:"schema"`
	ExitCode          int        `json:"execution_exit_code"`
	SelectionVerified bool       `json:"selection_verified"`
	HTTPRequests      *uint64    `json:"http_requests"`
	SourceCommit      []uint32   `json:"source_commit"`
	SourceArchive     []uint32   `json:"source_archive_sha256"`
	ToolchainArchive  []uint32   `json:"toolchain_archive_sha256"`
	InputSources      [][]uint32 `json:"input_sources_sha256"`
	CompiledSources   [][]uint32 `json:"compiled_sources_sha256"`
	Binaries          [][]uint32 `json:"binary_sha256"`
	ColdBase          []int64    `json:"cold_baseline_ns"`
	ColdCandidate     []int64    `json:"cold_candidate_ns"`
	WarmBase          []int64    `json:"warm_baseline_ns"`
	WarmCandidate     []int64    `json:"warm_candidate_ns"`
}

func digestNumbers(text string, size int) ([]uint32, error) {
	raw, err := hex.DecodeString(text)
	if err != nil || len(raw) != size {
		return nil, fmt.Errorf("digest shape mismatch")
	}
	result := make([]uint32, len(raw))
	for i, value := range raw {
		result[i] = uint32(value)
	}
	return result, nil
}

func TestMain(m *testing.M) {
	flag.Parse()
	code := m.Run()
	if os.Getenv("AI_GH_COUNTER_FIXTURE_ROLE") != "" {
		os.Exit(code)
	}
	root := filepath.Dir(os.Getenv("AI_GH_COUNTER_FIXTURE_INSTRUMENTED"))
	if root == "." {
		os.Exit(code)
	}
	var manifest struct {
		Pins      map[string]string `json:"pins"`
		Artifacts map[string]struct {
			SHA string `json:"sha256"`
		} `json:"artifacts"`
		Input struct {
			Schema int               `json:"schema"`
			Files  map[string]string `json:"files"`
		} `json:"counter_source_binding"`
		Compiled struct {
			Schema int               `json:"schema"`
			Files  map[string]string `json:"files"`
		} `json:"compiled_counter_source_binding"`
	}
	raw, err := os.ReadFile(filepath.Join(root, "build.json"))
	if err != nil || json.Unmarshal(raw, &manifest) != nil {
		os.Exit(98)
	}
	receipt := numericReceipt{Schema: 1, ExitCode: code, SelectionVerified: flag.Lookup("test.run").Value.String() == "^TestWindows", ColdBase: measured.coldBase, ColdCandidate: measured.coldCandidate, WarmBase: measured.warmBase, WarmCandidate: measured.warmCandidate}
	receipt.SourceCommit, err = digestNumbers(manifest.Pins["upstream_commit"], 20)
	if err != nil {
		os.Exit(98)
	}
	receipt.SourceArchive, err = digestNumbers(manifest.Pins["source_sha256"], 32)
	if err != nil {
		os.Exit(98)
	}
	receipt.ToolchainArchive, err = digestNumbers(manifest.Pins["toolchain_sha256"], 32)
	if err != nil {
		os.Exit(98)
	}
	files := []string{"httpcounter.go", "httpcounter_test.go", "channel.go", "channel_linux.go", "channel_windows.go", "channel_unsupported.go", "channel_windows_test.go", "windows_cli_fixture_test.go", "native_fixture.ps1"}
	if manifest.Input.Schema != 1 || manifest.Compiled.Schema != 1 || len(manifest.Input.Files) != len(files) || len(manifest.Compiled.Files) != len(files) {
		os.Exit(98)
	}
	for _, name := range files {
		digest, err := digestNumbers(manifest.Input.Files[name], 32)
		if err != nil {
			os.Exit(98)
		}
		receipt.InputSources = append(receipt.InputSources, digest)
		digest, err = digestNumbers(manifest.Compiled.Files[name], 32)
		if err != nil {
			os.Exit(98)
		}
		receipt.CompiledSources = append(receipt.CompiledSources, digest)
	}
	for _, name := range []string{"baseline", "instrumented", "native_fixture"} {
		digest, err := digestNumbers(manifest.Artifacts[name].SHA, 32)
		if err != nil {
			os.Exit(98)
		}
		receipt.Binaries = append(receipt.Binaries, digest)
	}
	file, err := os.OpenFile(filepath.Join(root, "numeric-result.json"), os.O_WRONLY|os.O_CREATE|os.O_EXCL, 0600)
	if err != nil {
		os.Exit(98)
	}
	err = json.NewEncoder(file).Encode(receipt)
	closeErr := file.Close()
	if err != nil || closeErr != nil {
		os.Exit(98)
	}
	os.Exit(code)
}

func strictMetadata(raw []byte) bool {
	if len(raw) > 4096 {
		return false
	}
	lines := bytes.Split(bytes.TrimSuffix(raw, []byte("\n")), []byte("\n"))
	if len(lines) != 2 {
		return false
	}
	for i, line := range lines {
		decoder := json.NewDecoder(bytes.NewReader(line))
		token, err := decoder.Token()
		if err != nil || token != json.Delim('{') {
			return false
		}
		seen := map[string]bool{}
		for decoder.More() {
			token, err = decoder.Token()
			if err != nil {
				return false
			}
			key, ok := token.(string)
			if !ok || seen[key] {
				return false
			}
			seen[key] = true
			var value json.RawMessage
			if decoder.Decode(&value) != nil {
				return false
			}
			switch key {
			case "schema":
				if string(value) != "1" {
					return false
				}
			case "started":
				if i != 0 || string(value) != "true" {
					return false
				}
			case "finished":
				if i != 1 || string(value) != "true" {
					return false
				}
			case "incomplete":
				if i != 1 || (string(value) != "true" && string(value) != "false") {
					return false
				}
			case "http_requests":
				if i != 1 || string(value) != "null" {
					return false
				}
			case "observed_completed_writes", "failed_write_attempts", "observed_external_writes":
				var count uint64
				if i != 1 || json.Unmarshal(value, &count) != nil || count > 1000000000 {
					return false
				}
			default:
				return false
			}
		}
		if _, err = decoder.Token(); err != nil {
			return false
		}
		if _, err = decoder.Token(); err != io.EOF {
			return false
		}
		if i == 0 && len(seen) != 2 || i == 1 && len(seen) != 7 {
			return false
		}
	}
	return true
}

func TestWindowsStrictMetadataUnknown(t *testing.T) {
	valid := runChannelChild(t, "finish", false)
	if !strictMetadata(valid) {
		t.Fatal("valid record refused")
	}
	for _, raw := range [][]byte{nil, []byte("fake-private-token"), append(valid, []byte("{}\n")...), bytes.Replace(valid, []byte(`"schema":1`), []byte(`"schema":1,"schema":1`), 1), bytes.Repeat([]byte("x"), 4097)} {
		if strictMetadata(raw) {
			t.Fatal("malformed record admitted")
		}
	}
}

func TestWindowsMetadataHasNoHttpData(t *testing.T) {
	raw := runChannelChild(t, "finish", false)
	if !strictMetadata(raw) {
		t.Fatal("numeric schema failed")
	}
}

func TestWindowsMetadataLifetimeBound(t *testing.T) {
	final := map[string]interface{}{"schema": 1, "finished": true, "observed_completed_writes": ^uint64(0), "failed_write_attempts": ^uint64(0), "observed_external_writes": ^uint64(0), "incomplete": false, "http_requests": nil}
	raw, err := json.Marshal(final)
	if err != nil || len(raw)+1+len("{\"schema\":1,\"started\":true}\n") > channelLifetimeBound {
		t.Fatal("lifetime encoding bound exceeded")
	}
}

func TestWindowsNumericReceiptSchema(t *testing.T) {
	for _, text := range []string{"", "fake-secret", strings.Repeat("00", 31), strings.Repeat("gg", 32)} {
		if _, err := digestNumbers(text, 32); err == nil {
			t.Fatal("invalid digest admitted")
		}
	}
	value, err := digestNumbers(strings.Repeat("ab", 32), 32)
	if err != nil || len(value) != 32 {
		t.Fatal("numeric digest unavailable")
	}
	raw, err := json.Marshal(numericReceipt{Schema: 1, HTTPRequests: nil, SourceArchive: value})
	if err != nil || bytes.Contains(raw, []byte("fake-secret")) {
		t.Fatal("numeric receipt leaked diagnostics")
	}
}

type cliResult struct {
	out, err, metadata []byte
	status             int
	elapsed            time.Duration
}

func pairedCommand(t *testing.T, instrumented bool, endpoint string, args ...string) cliResult {
	t.Helper()
	started := time.Now()
	key := "AI_GH_COUNTER_FIXTURE_BASELINE"
	if instrumented {
		key = "AI_GH_COUNTER_FIXTURE_INSTRUMENTED"
	}
	image := os.Getenv(key)
	if image == "" {
		t.Fatal("locked paired image required")
	}
	ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
	defer cancel()
	cmd := exec.CommandContext(ctx, image, append([]string{"api", endpoint}, args...)...)
	var out, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &stderr
	cmd.Env = fixtureEnv("", nil)
	// All fixture commands use absolute loopback HTTP, never production GH.
	for _, key := range []string{"GH_HOST", "GH_TOKEN", "GH_ENTERPRISE_TOKEN", "GITHUB_TOKEN", "GH_CONFIG_DIR", "HTTP_PROXY", "HTTPS_PROXY", "ALL_PROXY", "GH_DEBUG", "GH_PATH", "GH_TELEMETRY", "GH_TELEMETRY_ENDPOINT_URL", "GH_TELEMETRY_SAMPLE_RATE"} {
		prefix := strings.ToUpper(key) + "="
		filtered := cmd.Env[:0]
		for _, entry := range cmd.Env {
			if !strings.HasPrefix(strings.ToUpper(entry), prefix) {
				filtered = append(filtered, entry)
			}
		}
		cmd.Env = filtered
	}
	config := os.Getenv("AI_GH_COUNTER_FIXTURE_CONFIG")
	if config == "" {
		config = t.TempDir()
	}
	cmd.Env = append(cmd.Env, "GH_HOST=github.com", "GH_TOKEN=fake-private-token", "GH_CONFIG_DIR="+config, "GH_PROMPT_DISABLED=1", "GH_NO_UPDATE_NOTIFIER=1")
	if telemetry := os.Getenv("AI_GH_COUNTER_FIXTURE_TELEMETRY_URL"); telemetry != "" {
		os.WriteFile(filepath.Join(config, "config.yml"), []byte("version: \"1\"\ntelemetry: enabled\n"), 0600)
		cmd.Env = append(cmd.Env, "GH_TELEMETRY=enabled", "GH_TELEMETRY_SAMPLE_RATE=100", "GH_TELEMETRY_ENDPOINT_URL="+telemetry)
	} else {
		cmd.Env = append(cmd.Env, "GH_TELEMETRY=disabled")
	}
	var read, write *os.File
	var raw []byte
	drained := make(chan struct{})
	if instrumented {
		read, write = fixturePipe(t)
		parsed, _ := url.Parse(endpoint)
		cmd.Env = append(cmd.Env, "AI_GH_HTTP_COUNTER_HANDLE="+fmtHandle(write), "AI_GH_HTTP_COUNTER_HOST="+parsed.Host)
		cmd.SysProcAttr = &syscall.SysProcAttr{AdditionalInheritedHandles: []syscall.Handle{syscall.Handle(write.Fd())}}
		go func() { raw, _ = io.ReadAll(io.LimitReader(read, 4097)); close(drained) }()
	}
	if cmd.Start() != nil {
		if write != nil {
			write.Close()
			read.Close()
			<-drained
		}
		t.Fatal("paired command start failed")
	}
	if write != nil {
		write.Close()
	}
	err := cmd.Wait()
	result := cliResult{out: out.Bytes(), err: stderr.Bytes()}
	if err != nil {
		result.status = cmd.ProcessState.ExitCode()
	}
	if instrumented {
		select {
		case <-drained:
		case <-time.After(5 * time.Second):
			read.Close()
			<-drained
			t.Fatal("metadata leaked to descendant")
		}
		result.metadata = raw
		if !strictMetadata(raw) {
			t.Fatal("metadata incomplete or malformed")
		}
	}
	result.elapsed = time.Since(started)
	return result
}

func fmtHandle(file *os.File) string { return strconv.FormatUint(uint64(file.Fd()), 10) }

func requireParity(t *testing.T, baseline, observed cliResult) {
	t.Helper()
	if baseline.status != observed.status || !bytes.Equal(baseline.out, observed.out) || !bytes.Equal(baseline.err, observed.err) {
		t.Fatal("paired streams or status changed")
	}
}

func TestWindowsTrustedServerLedger(t *testing.T) {
	var ledger atomic.Uint64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ledger.Add(1)
		if r.URL.Query().Get("page") == "" {
			w.Header().Set("Link", "<http://"+r.Host+"/fixture?page=2>; rel=\"next\"")
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[1]\n"))
	}))
	defer server.Close()
	baseline := pairedCommand(t, false, server.URL+"/fixture", "--paginate")
	before := ledger.Load()
	observed := pairedCommand(t, true, server.URL+"/fixture", "--paginate")
	requireParity(t, baseline, observed)
	if before != 2 || ledger.Load()-before != 2 {
		t.Fatal("ledger pagination mismatch")
	}
	var final struct {
		Writes uint64 `json:"observed_completed_writes"`
	}
	json.Unmarshal(bytes.Split(observed.metadata, []byte("\n"))[1], &final)
	if final.Writes != 2 {
		t.Fatal("observed ledger mismatch")
	}
}

func TestWindowsHiddenRetryLedger(t *testing.T) {
	var ledger atomic.Uint64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ordinal := ledger.Add(1)
		if r.URL.Query().Get("page") == "2" && ordinal%3 == 2 {
			connection, _, err := w.(http.Hijacker).Hijack()
			if err == nil {
				connection.Close()
			}
			return
		}
		if r.URL.Query().Get("page") == "" {
			w.Header().Set("Link", "<http://"+r.Host+"/fixture?page=2>; rel=\"next\"")
		}
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("[1]\n"))
	}))
	defer server.Close()
	baseline := pairedCommand(t, false, server.URL+"/fixture", "--paginate")
	before := ledger.Load()
	observed := pairedCommand(t, true, server.URL+"/fixture", "--paginate")
	requireParity(t, baseline, observed)
	var final struct {
		Writes uint64 `json:"observed_completed_writes"`
	}
	json.Unmarshal(bytes.Split(observed.metadata, []byte("\n"))[1], &final)
	if before != 3 || ledger.Load()-before != 3 || final.Writes != 3 {
		t.Fatal("hidden retry ledger mismatch")
	}
}

func TestWindowsExternalRedirectLedger(t *testing.T) {
	var primary, external atomic.Uint64
	destination := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		external.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{\"secret\":\"fake-private-body\"}\n"))
	}))
	defer destination.Close()
	origin := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		primary.Add(1)
		http.Redirect(w, r, destination.URL+"/?secret=fake-private-query", 302)
	}))
	defer origin.Close()
	baseline := pairedCommand(t, false, origin.URL, "-H", "X-Fixture-Secret: fake-private-header")
	observed := pairedCommand(t, true, origin.URL, "-H", "X-Fixture-Secret: fake-private-header")
	requireParity(t, baseline, observed)
	var final struct {
		Writes   uint64 `json:"observed_completed_writes"`
		External uint64 `json:"observed_external_writes"`
	}
	json.Unmarshal(bytes.Split(observed.metadata, []byte("\n"))[1], &final)
	if primary.Load() != 2 || external.Load() != 2 || final.Writes != 1 || final.External != 1 {
		t.Fatal("redirect ledger mismatch")
	}
	for _, secret := range []string{"fake-private-body", "fake-private-query", "fake-private-header", "fake-private-token"} {
		if bytes.Contains(observed.metadata, []byte(secret)) {
			t.Fatal("HTTP data entered metadata")
		}
	}
}

func TestWindowsArgvStdioStatusParity(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{\"unicode\":\"雪\"}\n"))
	}))
	defer server.Close()
	baseline := pairedCommand(t, false, server.URL+"/fixture", "-H", "X-Fixture: spaces snow雪 quote\" trailing\\")
	observed := pairedCommand(t, true, server.URL+"/fixture", "-H", "X-Fixture: spaces snow雪 quote\" trailing\\")
	requireParity(t, baseline, observed)
}

func TestWindowsVerifiedImageUseRace(t *testing.T) {
	path := os.Getenv("AI_GH_COUNTER_FIXTURE_INSTRUMENTED")
	if path == "" {
		t.Fatal("locked image required")
	}
	if file, err := os.OpenFile(path, os.O_WRONLY, 0); err == nil {
		file.Close()
		t.Fatal("verified image writable")
	}
	if os.Rename(path, path+".forbidden") == nil {
		t.Fatal("verified image replaceable")
	}
}

func TestWindowsLockedAncestorUseRace(t *testing.T) {
	root := filepath.Dir(os.Getenv("AI_GH_COUNTER_FIXTURE_INSTRUMENTED"))
	if root == "." {
		t.Fatal("locked ancestor required")
	}
	if os.Rename(root, root+".forbidden") == nil {
		t.Fatal("verified ancestor replaceable")
	}
}

func TestWindowsNativeChildParity(t *testing.T) {
	var telemetry, requests atomic.Uint64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/telemetry" {
			telemetry.Add(1)
			w.WriteHeader(204)
			return
		}
		requests.Add(1)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{}\n"))
	}))
	defer server.Close()
	t.Setenv("AI_GH_COUNTER_FIXTURE_TELEMETRY_URL", server.URL+"/telemetry")
	baseline := pairedCommand(t, false, server.URL+"/fixture")
	deadline := time.Now().Add(5 * time.Second)
	for telemetry.Load() < 1 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if telemetry.Load() != 1 {
		t.Fatal("baseline detached telemetry unknown")
	}
	observed := pairedCommand(t, true, server.URL+"/fixture")
	deadline = time.Now().Add(5 * time.Second)
	for telemetry.Load() < 2 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if telemetry.Load() != 2 || requests.Load() != 2 {
		t.Fatal("detached telemetry lifecycle changed")
	}
	requireParity(t, baseline, observed)
	var final struct {
		Writes uint64  `json:"observed_completed_writes"`
		Total  *uint64 `json:"http_requests"`
	}
	json.Unmarshal(bytes.Split(observed.metadata, []byte("\n"))[1], &final)
	if final.Writes != 1 || final.Total != nil {
		t.Fatal("detached child falsely included")
	}
}

func cancelledCommand(t *testing.T, instrumented, console bool, endpoint string, arrived <-chan struct{}) cliResult {
	t.Helper()
	key := "AI_GH_COUNTER_FIXTURE_BASELINE"
	if instrumented {
		key = "AI_GH_COUNTER_FIXTURE_INSTRUMENTED"
	}
	image := os.Getenv(key)
	if image == "" {
		t.Fatal("locked cancellation image required")
	}
	cmd := exec.Command(image, "api", endpoint)
	cmd.Env = append(fixtureEnv("", nil), "GH_TOKEN=fake-private-token", "GH_HOST=github.com", "GH_CONFIG_DIR="+t.TempDir(), "GH_TELEMETRY=disabled", "GH_NO_UPDATE_NOTIFIER=1", "GH_PROMPT_DISABLED=1")
	var out, stderr bytes.Buffer
	cmd.Stdout, cmd.Stderr = &out, &stderr
	cmd.SysProcAttr = &syscall.SysProcAttr{CreationFlags: windows.CREATE_NEW_PROCESS_GROUP}
	var read, write *os.File
	var raw []byte
	drained := make(chan struct{})
	if instrumented {
		read, write = fixturePipe(t)
		parsed, _ := url.Parse(endpoint)
		cmd.Env = append(cmd.Env, "AI_GH_HTTP_COUNTER_HANDLE="+fmtHandle(write), "AI_GH_HTTP_COUNTER_HOST="+parsed.Host)
		cmd.SysProcAttr.AdditionalInheritedHandles = []syscall.Handle{syscall.Handle(write.Fd())}
		go func() { raw, _ = io.ReadAll(io.LimitReader(read, 4097)); close(drained) }()
	}
	if cmd.Start() != nil {
		if write != nil {
			write.Close()
			read.Close()
			<-drained
		}
		t.Fatal("cancellation child start failed")
	}
	if write != nil {
		write.Close()
	}
	select {
	case <-arrived:
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		cmd.Wait()
		t.Fatal("cancellation request not received")
	}
	if console {
		if windows.GenerateConsoleCtrlEvent(windows.CTRL_BREAK_EVENT, uint32(cmd.Process.Pid)) != nil {
			cmd.Process.Kill()
			cmd.Wait()
			t.Fatal("console cancellation unknown")
		}
	} else {
		cmd.Process.Kill()
	}
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		<-done
		t.Fatal("cancellation did not stop primary")
	}
	if instrumented {
		select {
		case <-drained:
		case <-time.After(5 * time.Second):
			read.Close()
			<-drained
			t.Fatal("cancelled metadata handle leaked")
		}
	}
	return cliResult{out: out.Bytes(), err: stderr.Bytes(), status: cmd.ProcessState.ExitCode(), metadata: raw}
}

func cancellationPair(t *testing.T, console bool) {
	arrived := make(chan struct{}, 4)
	var ledger atomic.Uint64
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		ledger.Add(1)
		arrived <- struct{}{}
		<-r.Context().Done()
	}))
	defer server.Close()
	b := cancelledCommand(t, false, console, server.URL, arrived)
	c := cancelledCommand(t, true, console, server.URL, arrived)
	requireParity(t, b, c)
	if ledger.Load() != 2 {
		t.Fatal("cancellation replay detected")
	}
	if strictMetadata(c.metadata) {
		t.Fatal("forced termination falsely complete")
	}
}

func TestWindowsCancellationNoReplay(t *testing.T) { cancellationPair(t, false) }

func TestWindowsConsoleCancellationParity(t *testing.T) {
	console, err := windows.CreateFile(windows.StringToUTF16Ptr("CONIN$"), windows.GENERIC_READ, windows.FILE_SHARE_READ|windows.FILE_SHARE_WRITE, nil, windows.OPEN_EXISTING, 0, 0)
	if err != nil {
		t.Fatal("console unavailable: cancellation qualification unknown")
	}
	defer windows.CloseHandle(console)
	var mode uint32
	if windows.GetConsoleMode(console, &mode) != nil {
		t.Fatal("console mode unavailable: qualification unknown")
	}
	cancellationPair(t, true)
}

func TestWindowsMissingFinishAndCrashUnknown(t *testing.T) {
	r, w := fixturePipe(t)
	cmd := nativeChild(t, "crash", w)
	if cmd.Start() != nil {
		t.Fatal("crash fixture start failed")
	}
	w.Close()
	if cmd.Wait() == nil {
		t.Fatal("crash status lost")
	}
	raw, _ := io.ReadAll(io.LimitReader(r, 4097))
	if strictMetadata(raw) {
		t.Fatal("missing final classified complete")
	}
}

func TestWindowsClosedReaderIsUnknown(t *testing.T) {
	r, w := fixturePipe(t)
	r.Close()
	cmd := nativeChild(t, "finish", w)
	if cmd.Start() != nil {
		t.Fatal("closed reader child failed to start")
	}
	w.Close()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	select {
	case <-done:
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		<-done
		t.Fatal("closed reader blocked CLI")
	}
	// Channel is absent; no count or completion can be reconstructed.
	if strictMetadata(nil) {
		t.Fatal("absent channel classified complete")
	}
}

func TestWindowsPairedOverhead(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte("{}\n"))
	}))
	defer server.Close()
	for _, group := range []string{"cold", "warm"} {
		t.Run(group, func(t *testing.T) {
			if group == "warm" {
				t.Setenv("AI_GH_COUNTER_FIXTURE_CONFIG", t.TempDir())
				pairedCommand(t, false, server.URL)
				pairedCommand(t, true, server.URL)
			}
			var baseline, candidate []int64
			var baseTotal, candidateTotal int64
			for i := 0; i < 20; i++ {
				var b, c cliResult
				if i%2 == 0 {
					b = pairedCommand(t, false, server.URL)
					c = pairedCommand(t, true, server.URL)
				} else {
					c = pairedCommand(t, true, server.URL)
					b = pairedCommand(t, false, server.URL)
				}
				requireParity(t, b, c)
				baseline = append(baseline, b.elapsed.Nanoseconds())
				candidate = append(candidate, c.elapsed.Nanoseconds())
				baseTotal += b.elapsed.Nanoseconds()
				candidateTotal += c.elapsed.Nanoseconds()
			}
			measured.Lock()
			if group == "cold" {
				measured.coldBase, measured.coldCandidate = baseline, candidate
			} else {
				measured.warmBase, measured.warmCandidate = baseline, candidate
			}
			measured.Unlock()
			sortedBase, sortedCandidate := append([]int64(nil), baseline...), append([]int64(nil), candidate...)
			sort.Slice(sortedBase, func(i, j int) bool { return sortedBase[i] < sortedBase[j] })
			sort.Slice(sortedCandidate, func(i, j int) bool { return sortedCandidate[i] < sortedCandidate[j] })
			if sortedCandidate[18]*100 > sortedBase[18]*105 || candidateTotal*100 > baseTotal*105 {
				t.Fatal("paired overhead gate failed")
			}
		})
	}
}
