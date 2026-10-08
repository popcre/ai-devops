//go:build !linux && !windows

package httpcounter

import "os"

func openChannel(string, string) *os.File { return nil }
