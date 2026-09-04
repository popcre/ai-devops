# Grok Build baseline BEFORE the 1.0.13 upgrade

Captured: 2026-09-04T00:46Z on EDGE-DEV (Windows).
Repo HEAD at capture: 71bfed6eb12f252e8f3996e91038519958c9aae9
origin/main at capture: 71bfed6eb12f252e8f3996e91038519958c9aae9
git status --short: 1 entries

## grok --version
```
grok 1.0.5 (5115b46bc9) [stable]
```

## grok update --help (exact-version install path)
```
Check for updates or install a specific version

Usage: grok update [OPTIONS]

Options:
      --check                 Check for updates without installing
      --json                  Emit machine-readable JSON output (for --check)
      --force-reinstall       Force re-download and install even if already up to date
      --version <VERSION>     Install a specific version (e.g. 0.1.150 or 0.1.151-alpha.2)
      --alpha                 Switch to the alpha release channel (faster updates, may have bugs)
      --stable                Switch to the stable release channel (default, weekly releases)
      --debug                 Enable debug logging
      --debug-file <FILE>     Write debug logs to FILE
  -h, --help                  Print help
      --leader-socket <PATH>  Use a custom leader socket path instead of the default `~/.grok/leader.sock`
```

## grok update --check --json
```
{"currentVersion":"1.0.5","latestVersion":"1.0.13","updateAvailable":true,"installer":"internal","channel":"stable","autoUpdate":null,"error":null}
```
