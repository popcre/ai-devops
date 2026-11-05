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
| `login zai --no-browser`, first attempt | Authorization window timed out; saved login unchanged. |
| `login zai --no-browser`, authorized by owner's yes, 8:09 PM EST | Exit 0, "Login successful". **This is the fix.** |
| `--mode plan --json -p` after the new login | Exit 0, `response` "OK", `projection.status` "idle". |
| `ai-zcode ask`, `ai-zcode doctor --live` after the new login | Exit 0, "OK"; live probe ok, all checks green. |

The new login left the provider rule and default model in
`provider_config.json` unchanged. All runs had the desktop app open: a run with
it closed was not tested, to avoid disturbing open sessions. Why the saved login
went invalid, and why the Oct 19 re-login did not last, is not known.

Root cause evidence: `POST https://api.z.ai/api/auth/z/login` with the saved
Z.AI login returns HTTP 200 with body code 500, "Z.ai user information is
invalid". The CLI reports that as `project_token_login_failed`.

`bin/ai-zcode` STEP 0 cites this file. The parser-rejection and hook facts were
not re-probed here and still rest on the 2026-09-17 evidence.
