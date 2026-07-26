---
name: write-tool-mangles-literal-control-chars
description: The Write/Edit tools drop literal control chars and JS escape sequences from file content — build them with String.fromCharCode instead.
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9b09f257-7b1d-4dc1-9ffb-12d134d4b536
---

When writing source that must contain control characters (CR, ESC, NUL, U+2028,
bidi overrides like U+202E), literal control bytes and `\r`/`\x1b`-style escapes
typed into Write/Edit `content` do **not** survive into the file — they arrive
stripped or as the wrong bytes, and a later Edit whose `old_string` contains them
fails to match. Cost several wasted iterations building `preview-format.ts`.

**How to apply:** construct control/invisible chars at runtime —
`String.fromCharCode(0x0d)`, `String.fromCharCode(0x202e)` — in both the source
under test and the tests, and match on code points numerically rather than on
literal chars. Verify no literal control bytes leaked with:
`LC_ALL=C grep -nP '[\x00-\x08\x0b-\x1f\x7f]' <file>` (expect no matches).

Surfaced 2026-07-17 hardening the nas-mcp write-approval preview against
markdown/terminal/bidi spoofing (commit 9346469).
