//go:build windows

package httpcounter

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
	"unsafe"

	"golang.org/x/sys/windows"
)

func fixturePipe(t *testing.T) (*os.File, *os.File) {
	t.Helper()
	// Protected DACL grants only current owner and SYSTEM. No named endpoint.
	sd, err := windows.SecurityDescriptorFromString("D:P(A;;GA;;;OW)(A;;GA;;;SY)")
	if err != nil {
		t.Fatal("private pipe ACL unavailable")
	}
	sa := windows.SecurityAttributes{SecurityDescriptor: sd, InheritHandle: 1}
	sa.Length = uint32(unsafe.Sizeof(sa))
	var read, write windows.Handle
	if windows.CreatePipe(&read, &write, &sa, 4096) != nil {
		t.Fatal("private pipe unavailable")
	}
	r, w := os.NewFile(uintptr(read), "fixture-reader"), os.NewFile(uintptr(write), "fixture-writer")
	if windows.SetHandleInformation(read, windows.HANDLE_FLAG_INHERIT, 0) != nil {
		r.Close()
		w.Close()
		t.Fatal("reader inheritance unavailable")
	}
	var flags, outSize, inSize, instances uint32
	if windows.GetNamedPipeInfo(read, &flags, &outSize, &inSize, &instances) != nil || flags&windows.PIPE_SERVER_END == 0 || inSize <= channelLifetimeBound {
		r.Close()
		w.Close()
		t.Fatal("directional pipe capacity unknown")
	}
	t.Cleanup(func() { r.Close(); w.Close() })
	return r, w
}

func fixtureEnv(role string, writer *os.File) []string {
	// Qualification children receive a positive fixture profile, never the
	// operator's credentials, pager, loader or executable-selection variables.
	root, err := windows.GetWindowsDirectory()
	if err != nil || !filepath.IsAbs(root) {
		panic("Windows runtime directory unavailable")
	}
	executable, err := os.Executable()
	if err != nil || !filepath.IsAbs(executable) {
		panic("bound fixture executable unavailable")
	}
	temporary := filepath.Join(filepath.Dir(executable), "temp")
	env := []string{"SYSTEMROOT=" + root, "WINDIR=" + root, "PATH=",
		"TEMP=" + temporary, "TMP=" + temporary, "HOME=" + temporary,
		"USERPROFILE=" + temporary, "XDG_CACHE_HOME=" + temporary, "GH_PAGER="}
	env = append(env, "AI_GH_COUNTER_FIXTURE_ROLE="+role)
	if writer != nil {
		env = append(env, "AI_GH_HTTP_COUNTER_HANDLE="+strconv.FormatUint(uint64(writer.Fd()), 10), "AI_GH_HTTP_COUNTER_HOST=fixture.invalid")
	}
	return env
}

func TestWindowsFixtureEnvironmentDoesNotInheritSelectors(t *testing.T) {
	for _, key := range []string{"PATH", "GH_PATH", "PAGER", "GH_PAGER", "GH_FORCE_TTY", "GIT_EXEC_PATH", "GIT_CONFIG_SYSTEM", "COMSPEC", "GH_TOKEN", "FUTURE_PROVIDER_SECRET"} {
		t.Setenv(key, "hostile-ambient-sentinel")
	}
	for _, item := range fixtureEnv("finish", nil) {
		if strings.Contains(item, "hostile-ambient-sentinel") {
			t.Fatal("ambient selector or credential inherited")
		}
	}
}

func nativeChild(t *testing.T, role string, writer *os.File) *exec.Cmd {
	t.Helper()
	executable, err := os.Executable()
	if err != nil {
		t.Fatal("fixture executable unknown")
	}
	cmd := exec.Command(executable, "-test.run=^TestWindowsFixtureChild$")
	cmd.Env = fixtureEnv(role, writer)
	cmd.SysProcAttr = &syscall.SysProcAttr{}
	if writer != nil {
		cmd.SysProcAttr.AdditionalInheritedHandles = []syscall.Handle{syscall.Handle(writer.Fd())}
	}
	return cmd
}

func TestWindowsFixtureChild(t *testing.T) {
	role := os.Getenv("AI_GH_COUNTER_FIXTURE_ROLE")
	if role == "" {
		return
	} // only the named parent establishes a child role
	for _, key := range []string{"AI_GH_HTTP_COUNTER_FD", "AI_GH_HTTP_COUNTER_HANDLE", "AI_GH_HTTP_COUNTER_HOST"} {
		if os.Getenv(key) != "" {
			os.Exit(91)
		}
	}
	if text := os.Getenv("AI_GH_COUNTER_SENTINEL_HANDLE"); text != "" {
		value, _ := strconv.ParseUint(text, 10, 64)
		var written uint32
		if windows.WriteFile(windows.Handle(value), []byte("forbidden"), &written, nil) == nil {
			os.Exit(97)
		}
	}
	switch role {
	case "finish":
		if state.pipe == nil {
			os.Exit(92)
		}
		Finish()
	case "grandchild":
		if state.pipe == nil {
			os.Exit(92)
		}
		child := nativeChild(t, "unobserved", nil)
		child.Env = append(child.Env, "AI_GH_COUNTER_STALE_HANDLE="+fmt.Sprint(state.pipe.Fd()))
		if child.Run() != nil {
			os.Exit(93)
		}
		Finish()
	case "unobserved":
		if state.pipe != nil {
			os.Exit(94)
		}
		if text := os.Getenv("AI_GH_COUNTER_STALE_HANDLE"); text != "" {
			value, _ := strconv.ParseUint(text, 10, 64)
			var written uint32
			if windows.WriteFile(windows.Handle(value), []byte("forbidden"), &written, nil) == nil {
				os.Exit(95)
			}
		}
	case "crash":
		os.Exit(17)
	default:
		os.Exit(96)
	}
	os.Exit(0)
}

func TestWindowsHandleTextRejectsInvalid(t *testing.T) {
	for _, text := range []string{"", "0", "-1", "abc", "18446744073709551615", "18446744073709551616", "1.5"} {
		if f := openChannel("", text); f != nil {
			f.Close()
			t.Fatal("invalid handle admitted")
		}
	}
}

func TestWindowsHandleRejectsNonMetadata(t *testing.T) {
	for _, f := range []*os.File{os.Stdin, os.Stdout, os.Stderr} {
		if openChannel("", fmt.Sprint(f.Fd())) != nil {
			t.Fatal("standard handle admitted")
		}
	}
	f, err := os.CreateTemp(t.TempDir(), "ordinary")
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	if openChannel("", fmt.Sprint(f.Fd())) != nil {
		t.Fatal("ordinary file admitted")
	}
	f.Close()
	if openChannel("", fmt.Sprint(f.Fd())) != nil {
		t.Fatal("closed file admitted")
	}
}

func TestWindowsMsysFDIsNotHandle(t *testing.T) {
	if openChannel("3", "") != nil || openChannel("3", "4") != nil {
		t.Fatal("POSIX descriptor admitted")
	}
}

func runChannelChild(t *testing.T, role string, paused bool) []byte {
	t.Helper()
	r, w := fixturePipe(t)
	cmd := nativeChild(t, role, w)
	if err := cmd.Start(); err != nil {
		t.Fatal("native child start failed")
	}
	w.Close()
	done := make(chan error, 1)
	go func() { done <- cmd.Wait() }()
	var raw []byte
	var err error
	drained := make(chan struct{})
	if !paused {
		go func() { raw, err = io.ReadAll(io.LimitReader(r, 4097)); close(drained) }()
	}
	select {
	case wait := <-done:
		if wait != nil {
			t.Fatal("native child failed")
		}
	case <-time.After(10 * time.Second):
		cmd.Process.Kill()
		<-done
		t.Fatal("metadata blocked child")
	}
	if paused {
		go func() { raw, err = io.ReadAll(io.LimitReader(r, 4097)); close(drained) }()
	}
	select {
	case <-drained:
	case <-time.After(5 * time.Second):
		r.Close()
		<-drained
		t.Fatal("metadata writer leaked to descendant")
	}
	if err != nil || len(raw) > channelLifetimeBound || !bytes.Contains(raw, []byte(`"finished":true`)) {
		t.Fatal("bounded final missing")
	}
	return raw
}

func TestWindowsPausedReaderDoesNotBlock(t *testing.T) { runChannelChild(t, "finish", true) }
func TestWindowsDirectionalCapacityGate(t *testing.T)  { runChannelChild(t, "finish", false) }
func TestWindowsReservedKeysCleared(t *testing.T)      { runChannelChild(t, "finish", false) }
func TestWindowsGrandchildCannotWrite(t *testing.T)    { runChannelChild(t, "grandchild", false) }

func TestWindowsInheritanceWhitelist(t *testing.T) {
	_, sentinel := fixturePipe(t)
	r, writer := fixturePipe(t)
	cmd := nativeChild(t, "grandchild", writer)
	cmd.Env = append(cmd.Env, "AI_GH_COUNTER_SENTINEL_HANDLE="+fmt.Sprint(sentinel.Fd()))
	if err := cmd.Start(); err != nil {
		t.Fatal("native child start failed")
	}
	writer.Close()
	if cmd.Wait() != nil {
		t.Fatal("inheritance fixture failed")
	}
	raw, _ := io.ReadAll(io.LimitReader(r, 4097))
	if !bytes.Contains(raw, []byte(`"finished":true`)) {
		t.Fatal("metadata final missing")
	}
}

func TestWindowsConcurrentChannelIsolation(t *testing.T) {
	// Independent parent-created writers. No global parent metadata state.
	for i := 0; i < 4; i++ {
		t.Run(fmt.Sprint(i), func(t *testing.T) { t.Parallel(); runChannelChild(t, "grandchild", false) })
	}
}
