@ping.exe -n 1 -w 800 %1 2>NUL | findstr /c:"TTL=" >NUL 2>&1
