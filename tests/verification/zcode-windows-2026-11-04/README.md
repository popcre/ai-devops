# ZCode headless login diagnosis, 2026-11-04 (#1860)

Host: edge-dev (Windows 11). Desktop 3.17.2.9661, CLI core 0.17.1. Run 5:20 to
6:15 PM EST. No secret values were printed or stored.

Every run used the wrapper's provider env and the prompt
`Reply with the word OK only.`

| Route | Result |
|---|---|
| `zcode doctor` | Exit 0. Reports runtime only, nothing about login. |
| `--mode plan --json -p` | Exit 1, `project_token_login_failed`. |
| Same plus `--surface desktop`, desktop app running | Exit 1, same error. |
| `app-server --surface desktop` | Session starts. Turn fails `CONFIGURATION_ERROR`, "Select a model before continuing", with an empty model list. Not usable without what the desktop host supplies. |
| `login bigmodel` | Not tried. Needs browser authorization; account support unknown. |
| `login zai --no-browser` | Not completed. Authorization window timed out; saved login unchanged. |

Root cause evidence: `POST https://api.z.ai/api/auth/z/login` with the saved
Z.AI login returns HTTP 200 with body code 500, "Z.ai user information is
invalid". The CLI reports that as `project_token_login_failed`.

This does not requalify STEP 0 in `bin/ai-zcode`: no route has returned an
answer yet.
