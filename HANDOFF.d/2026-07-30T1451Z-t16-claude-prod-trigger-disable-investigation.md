# HANDOFF — Who disabled PROD Cloud Build triggers on 2026-07-20?

**Status:** Root cause and actor identified from GCP audit logs. One piece of
evidence still unretrieved (the t16 chat transcript, machine offline).
**Written:** 2026-07-22, from machine 916, session `997c6277-ee57-4f34-9b9b-9c3059d55663`.
**For:** whoever continues this on another computer (fresh session — assume zero prior knowledge).

---

## 1. The question being investigated

Albert asked whether any AI session (Claude Code or Codex) disabled **production**
Google Cloud Build triggers, or added/changed substitutions on triggers. He later
pinpointed the suspected time: **2026-07-20 around 21:06 UTC**.

## 2. What we CONFIRMED happened (from GCP audit logs — authoritative)

At **2026-07-20, 21:04–21:06 UTC**, a **`terraform apply`** ran against project
`lithe-breaker-323913`, region `us-east4`, and:

- Set **4 PROD triggers to `disabled = true`**:
  `popcre-core-prod`, `popcre-item-prod`, `popcre-sync-prod`, `popcre-tracking-prod`
  (NOT frontend-prod or bff-prod — those were untouched in this apply)
- Rewrote the full **substitutions** block on essentially all triggers
  (prod + staging + dev + sandbox).

**Actor / provenance (from the audit log requestMetadata):**
- Principal: `U2Giants@gmail.com` (Albert's own Google account)
- Source IP: `73.29.10.192` = **Albert's t16 computer** (confirmed by Albert)
- User-agent: `Terraform/1.15.6 ... terraform-provider-google` → it was `terraform apply`,
  NOT a `gcloud builds triggers` command.

**Interpretation:** Albert does NOT use Terraform. His developer Uma does, but Uma
works from an IP in India — this was t16's home IP, not Uma. The strong hypothesis
is that **an AI agent session on t16 ran `terraform apply` using Albert's local
gcloud credentials**, and that apply carried `disabled = true` on the prod triggers.

## 3. Current state (as of 2026-07-22) — NOT broken

All **6 prod triggers are ENABLED again**. They were reverted after 07-20:
- 2026-07-21 ~18:24–18:25 UTC — `UpdateBuildTrigger` by `devopswithkube@gmail.com` (Uma)
- 2026-07-22 ~04:42 UTC — `UpdateBuildTrigger` by `terraform-admin@lithe-breaker-323913.iam.gserviceaccount.com`

Verify anytime with:
```
gcloud builds triggers list --project=lithe-breaker-323913 --region=us-east4 --format="value(name,disabled)" | grep prod
```
(blank second column = enabled)

## 4. How the evidence was found (repro steps)

1. Grepped all local Claude transcripts (`~/.claude/projects`) and Codex sessions
   (`~/.codex/sessions`) on 916 — only sandbox trigger edits found, nothing prod,
   nothing disabled. No sessions existed on 916 dated 2026-07-20 at all.
2. Grepped the VPS (`ssh vps`, host `hetz`) transcripts for root + ai users
   (`/root` and `/home/ai`, both `.claude` and `.codex`) — clean; only one
   read-only `gcloud builds triggers list`.
3. The breakthrough was the **GCP audit log**, queried by service name:
```
gcloud logging read 'protoPayload.serviceName="cloudbuild.googleapis.com" AND protoPayload.methodName:"Trigger" AND timestamp>="2026-06-20T00:00:00Z"' --project=lithe-breaker-323913 --format="table(timestamp, protoPayload.authenticationInfo.principalEmail, protoPayload.methodName, protoPayload.resourceName)"
```
4. Detail of exactly what changed (disabled flags + substitutions per trigger):
```
gcloud logging read 'protoPayload.serviceName="cloudbuild.googleapis.com" AND protoPayload.methodName="google.devtools.cloudbuild.v1.CloudBuild.UpdateBuildTrigger" AND timestamp>="2026-07-20T21:04:00Z" AND timestamp<="2026-07-20T21:07:30Z"' --project=lithe-breaker-323913 --format=json
```
   Parse each entry's `protoPayload.request.trigger.{name, disabled, substitutions}`
   and `protoPayload.requestMetadata.{callerIp, callerSuppliedUserAgent}`.

## 5. What we TRIED that did NOT work / dead ends

- **`resource.type="build_trigger"` log filter returns NOTHING** — wrong resource
  type for Cloud Build. You MUST filter by `protoPayload.serviceName="cloudbuild.googleapis.com"`.
- Searching transcripts for `gcloud builds triggers disable/update` was a dead end:
  the change was Terraform, so no such CLI string exists in any chat.
- `--region=-` and `global` on `triggers list` return nothing — the triggers are in
  **`us-east4`**. Must specify that region.
- `dflow-plm` project has the Cloud Build API disabled — not where these triggers live.
  The triggers are in **`lithe-breaker-323913`**.
- Reaching **t16 live: impossible right now** — it's offline (Tailscale `100.96.221.71`,
  "last seen ~1h ago"). Its transcript backup in this repo (`claude_chats/t16/`) only
  covers up to **July 6**, so the July 20 session is NOT backed up.
- Reaching **4837**: online (Tailscale `100.123.87.44`) but SSH publickey denied,
  `C$` SMB denied, Tailscale SSH not enabled. Could not read it remotely. (4837 is
  probably not the culprit anyway — the IP points to t16.)

## 6. THE ONE OPEN ITEM — get t16's July 20 transcript

t16 is the machine that ran the apply. When it comes back online, retrieve the
session that ran `terraform apply` at ~21:04 UTC on 2026-07-20. On t16 (PowerShell):
```powershell
Get-ChildItem "$env:USERPROFILE\.claude\projects","$env:USERPROFILE\.codex\sessions" -Recurse -Filter *.jsonl |
  Select-String "terraform apply|disabled\s*=\s*true|cloudbuild_trigger|google_cloudbuild" -List | Select Path
```
Then back it up (there is a `claude-transcript-backup` skill / `claude_chats/sync.sh`
in this repo) so it lands in `claude_chats/t16/` and any machine can read it.

## 7. Root cause still to close

Find the **Terraform config** that declares those prod triggers with `disabled = true`
(likely in Uma's infrastructure repo). If the committed Terraform state/config has
prod triggers disabled, ANY future `terraform apply` will silently re-disable them.
That config is the real root cause and must be fixed, not just the live triggers.

## 8. Recommended follow-ups (offered, not yet done)

- **Log-based alert:** email Albert whenever any `UpdateBuildTrigger` sets
  `disabled=true` on a `*-prod` trigger in `lithe-breaker-323913`. Catches a repeat
  in minutes.
- **Policy question:** should AI agent sessions be able to run `terraform apply`
  against prod under Albert's personal gcloud credentials at all? Consider scoping
  down or requiring confirmation.

## 9. Environment / access facts for the next session

- gcloud on 916 is authed as `u2giants@gmail.com`; can read the audit logs above.
- Triggers project/region: **`lithe-breaker-323913` / `us-east4`**.
- VPS: `ssh vps` (aka `coolify`/`hetzner`), host `hetz`, users root + ai. Clean.
- t16 Tailscale `100.96.219...`/`100.96.221.71` (offline); 4837 `100.123.87.44`;
  916 `100.110.219.31`.
- This investigation's own chat transcript is backed up next to this file at
  `claude_chats/916/997c6277-ee57-4f34-9b9b-9c3059d55663.jsonl` — copy it into
  `~/.claude/projects/D--repos-ai-devops/` on another machine and run `claude --resume`
  to continue the exact session.
