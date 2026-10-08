//go:build linux

package httpcounter

import (
	"os"
	"strconv"
	"syscall"
)

func openChannel(fdText, handleText string) *os.File {
	if handleText != "" {
		return nil
	}
	fd, err := strconv.Atoi(fdText)
	if err != nil || fd < 3 || fd > 1024 {
		return nil
	}
	var stat syscall.Stat_t
	if syscall.Fstat(fd, &stat) != nil || stat.Mode&syscall.S_IFMT != syscall.S_IFIFO {
		return nil
	}
	syscall.CloseOnExec(fd)
	return os.NewFile(uintptr(fd), "httpcounter")
}
