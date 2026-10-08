//go:build windows

package httpcounter

import (
	"os"
	"strconv"

	"golang.org/x/sys/windows"
)

const channelLifetimeBound = 1024

func openChannel(fdText, handleText string) *os.File {
	if handleText == "" {
		return nil
	}
	value, err := strconv.ParseUint(handleText, 10, strconv.IntSize)
	if err != nil || value == 0 || uintptr(value) == ^uintptr(0) {
		return nil
	}
	handle := windows.Handle(value)
	for _, id := range []uint32{windows.STD_INPUT_HANDLE, windows.STD_OUTPUT_HANDLE, windows.STD_ERROR_HANDLE} {
		standard, err := windows.GetStdHandle(id)
		if err == nil && standard == handle {
			return nil
		}
	}
	kind, err := windows.GetFileType(handle)
	if err != nil || kind != windows.FILE_TYPE_PIPE {
		return nil
	}
	var flags, outSize, inSize, instances uint32
	if windows.GetNamedPipeInfo(handle, &flags, &outSize, &inSize, &instances) != nil || flags&windows.PIPE_SERVER_END != 0 {
		return nil
	}
	if windows.SetHandleInformation(handle, windows.HANDLE_FLAG_INHERIT, 0) != nil {
		return nil
	}
	if fdText != "" || inSize <= channelLifetimeBound {
		return nil
	}
	return os.NewFile(uintptr(handle), "httpcounter")
}
