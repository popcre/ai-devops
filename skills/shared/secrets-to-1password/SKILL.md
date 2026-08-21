---
name: secrets-to-1password
description: Store anything in the vibe_coding 1Password vault with a descriptive title, searchable tags, and notes detailed enough for a future AI session that has never seen the entry to find it, know what it is for, and use it without asking a single question. Use for EVERY create or update in the 1Password MCP (`note_create`, `password_create`, `item_edit`) — whether it is a secret (credential, token, API key, password, connection string, SSH key, login) or a plain non-secret information/config/reference note. Use whenever the user says "secrets sweep", "any secrets not in 1password?", "put this in 1Password", "save this key", "store these credentials", "add this note to the vault", "update that entry"; whenever a credential appears mid-session that isn't stored yet; whenever you're about to write a secret into a .env, doc, or scratch file instead; and as the secrets step of wrap-up and session-docs-update.
---

# secrets-to-1password

Albert's vault is not a junk drawer — it's the handoff mechanism between AI
sessions. An entry is only worth creating if a session six months from now, with
zero knowledge of today's conversation, can **find it, understand what it is, and
use it without asking Albert a single question.** That standard is the whole
point of this skill. A bare title and a pasted token is a failure; it forces a
future session to either guess or interrupt Albert, which is exactly the cost
this vault exists to avoid.

The vault already shows both outcomes. `Supabase Runtime Keys - shared POP
database (production)` is findable and self-explanatory. `coolify-secrets`, with
no tags and no notes, tells a future session nothing — it's a mystery blob
someone has to open and reverse-engineer. Write the first kind.

Shared by Claude and Codex/ChatGPT — the standard is identical in both. Claude
loads this skill automatically on the triggers above; Codex auto-loads nothing,
so read this file whenever a task will write to the 1Password MCP.

## Three ways in

This skill runs in any of these modes; the title/tags/notes standard below is
identical for all three, and applies to **every** create or update you make
through the MCP. If you are about to call `note_create`, `password_create`, or
`item_edit`, you are in this skill — there is no "quick save" path that skips
the standard.

- **Sweep** (from `wrap-up`, `session-docs-update`, or "secrets sweep"): scan the
  session for any credential that appeared — pasted in chat, printed by a
  command, read out of a `.env`, generated for a new service, or embedded in a
  URL or git remote. For each one, check whether it's already in the vault and
  store what isn't. If nothing turned up, say so explicitly rather than staying
  silent — "no secrets found" is a real result; silence reads as a skipped step.
- **Single entry** ("save this key"): you already have the one credential. Skip
  the scan and go straight to the rules.
- **Information entry** ("add this to the vault"): a note with no secret in it at
  all — a host layout, an account map, an endpoint list, "how service X is
  wired". These earn exactly the same discipline. Non-secret does not mean
  low-effort: an untitled, untagged, note-less info blob is just as useless to a
  future session as a mystery credential. The only difference is that the
  value-safety rules (3–5 below) have nothing to bite on, and every field can be
  plaintext `text` rather than `concealed`.

## Moving a secret VALUE safely

The global rule says values move only through pipes or protected files. This is
the operational detail behind it — read it before you touch a live credential.

**The failure this prevents.** A secret has leaked the moment it reaches
anywhere a human or a log can read it: a chat transcript, terminal scrollback,
an error message, a process list. On 2026-08-21 a live 1Password
service-account token was leaked into a chat transcript *minutes after it was
created to replace an earlier leak*, forcing a second rotation in one session.
Both leaks had the identical cause: the value sat in a command-line argument,
and a parse error echoed the whole command back.

**Allowed transports**

```bash
# pipe it — the value never becomes an argument
op read "op://vibe_coding/<item>/<field>" | ssh host 'umask 077; cat > /path/file'
```

- `op run --env-file …`, `op://` references, and the 1Password MCP `op_run` tool
  with `op://` values in `env` (protected injection — the tool redacts them).
- Write it straight into a `0600` file, then have the consumer read that file.

**Forbidden — each of these has leaked a real credential**

- ANY command-line argument: after a remote command string, in `--flag=value`,
  or as a `VAR=value cmd` prefix. On a parse error, a wrong argument position, or
  a non-zero exit, the shell echoes the whole command — permanently.
- Asking Albert to paste a secret into chat. Ask him to save it in 1Password and
  name the item; read it from there.
- `--reveal` into a terminal, or `echo`/`cat`/`grep` "just to check it looks
  right".
- Running any of this under `set -x`, a verbose/debug HTTP mode, or through a
  consumer that echoes stdin. A pipe is not safe if something downstream prints.

**Verify by fingerprint, never by printing**

```bash
printf '%s' "$value" | sha256sum | cut -c1-16
```

Use it to answer "is this the same token?", "did the write take?", "which of the
four service-account tokens is this?" — without the value ever being displayed.

**Containment is not remediation.** Removing a secret from one file does not
invalidate copies already taken. Before reporting a leak handled, sweep the whole
machine — `.bak-*` files, shell history, config files and their auto-backups,
setup scripts, archives — and say plainly that only rotation retires an exposed
value. Search by pattern and report PATHS ONLY; never print a matched line:

```bash
grep -rl "ops_eyJ" "$HOME" --exclude-dir=.cache      # paths, not contents
```

Rotation itself still needs Albert's approval. Report the compromise, ask, and
rotate only once he says yes.

## Hard rules

1. **Vault is always `vibe_coding`** — the only vault the service account can
   reach. Resolve its ID with `vault_list` rather than hardcoding; today it is
   `b2dsir4jze3wfygdxixoaasdeq`, and reading it live costs one call and survives
   a vault rebuild.
2. **Search before creating.** Run `item_lookup` on the vault for the service
   name, the app name, and the secret type. If a matching entry exists, `item_edit`
   it — a second near-duplicate entry is worse than none, because now a future
   session has to guess which one is live.
3. **Never paste secret values into files, docs, commits, or chat.** The value
   goes into the entry and nowhere else. To *use* a secret afterward, prefer
   `op_run` with an `op://vibe_coding/<item>/<field>` reference so the value never
   enters the transcript.
4. **Never rotate or overwrite an existing credential without Albert's
   approval.** Adding a new entry is safe; replacing a live value can break
   running apps. If the value you hold conflicts with what's stored, stop and ask.
5. **Never store a value you can't confirm is complete.** A truncated or
   placeholder secret is worse than no entry at all: it looks authoritative, so a
   future session wires it in, gets a 401, and burns a session finding out. If the
   value looks partial, stop and ask for the full one rather than saving it with a
   warning attached.
6. **Tags are mandatory** (see below). Untagged entries are the ones that rot.
7. **Report each entry back** with its title, item ID, and `op://` reference so
   Albert can see it landed.

Rules 4 and 5 collide often — you hold a value and something similar is already
stored. Resolve it by shape first (a Twilio auth token is 32 hex; a Supabase key
is a three-segment JWT), and if you still need to know whether two values match,
compare hashes rather than revealing either:

```
op_run: op read "op://vibe_coding/<item title>/<field>" | sha256sum
```

Compare that against the hash of the value you hold. Matching hashes mean it's
already stored and there's nothing to do. `item_get` with `reveal: true` would
answer the same question by printing a live production secret into the transcript
permanently — reach for the hash instead.

## Which tool to use

The MCP has no generic item-create tool, so category follows from the tool:

| What you're storing | Tool | Category |
|---|---|---|
| API key, token, connection string, service-account creds, multi-field env sets, SSH keys, anything that isn't a username+password login | `note_create` | SecureNote |
| A real login (username + password, usually with a URL) | `password_create` | Login |
| A standalone password with no username | `password_create` | Password |

The older `ApiCredentials` entries in the vault predate this MCP and can't be
recreated through it — use `note_create` with concealed fields for API keys and
match the good entries' structure, not those legacy ones' category.

Need a new password rather than storing an existing one? `password_generate`
(or `password_generate_memorable`) first, then create the item.

## Title format

`<What it is> - <App/scope> (<qualifier>)`

The title is the only thing `item_lookup` matches on, so it must contain the
words a future session would actually search: the service, the app, and the
environment. "Which one is this?" should never survive reading the title.

Good, from the vault:
- `Supabase DB Direct URL - The Oracle (CURRENT PROD, theoracle, <removed-protected-project-ref>)`
- `Designflow - Azure Graph client secret (AZURE_CLIENT_SECRET)`
- `logo.dev publishable token - popcrm-web`
- Info entry: `Hetz server layout - which apps run where (Coolify vs Ansible)`

Bad: `backend-secrets`, `api key`, `token`, `notes`, `new entry` — no app, no
environment, nothing to search on.

Include the qualifier whenever more than one of a thing can exist: prod vs
sandbox vs preview, which project ref, which machine, read-only vs read-write.
Distinguishing prod from sandbox in the title is what stops a future session
running a destructive command against production.

## Tags

Six to eight lowercase tags, drawn from these axes so that any reasonable search
angle lands on the entry:

- **service**: `supabase`, `github`, `cloudflare`, `azure`, `trigger.dev`
- **app/scope**: `popcrm`, `poppim`, `popdam`, `designflow`, `the-oracle`, `shared-db`, `hetz`
- **environment**: `production`, `sandbox`, `preview`, `local-env`
- **purpose**: `runtime-secrets`, `migrations`, `ci`, `github-actions`, `browser-test`, `api`, `read-only`, `reference`, `ai-session`

Reuse existing vault tags rather than inventing synonyms — `item_list` shows
what's already in use. A fresh tag nobody else uses helps no one find anything.

## Notes: the part that actually matters

Follow the shape of `Supabase Runtime Keys - shared POP database (production)`,
which is the best entry in the vault. Write for a stranger, not for yourself
today:

```
<One or two sentences: what this is and what system it belongs to.>

<Non-secret identifiers: project ref, URL, account, host, username, endpoint.>

Use cases for future AI sessions:
- <Concrete task this unlocks.>
- <Another.>

<Where it's used / who owns it: repos, file paths, containers, CI workflows.>

<Guardrails: what NOT to do with it, and which other entry to use instead.>

Created during the <YYYY-MM-DD> <topic> session because <why it needed storing>.
```

Each block earns its place:

- **Identifiers** stop a future session from having to reveal the secret just to
  work out which project it points at. Non-secret context belongs in plaintext.
- **Use cases** are the difference between an entry that gets used and one that
  gets ignored. A session searching "how do I run migrations" needs to recognize
  this entry as the answer.
- **Ownership** answers "if I change this, what breaks?" Name the repo and the
  path. Remember the scope boundary: host-level things on `hetz` are owned by
  `u2giants/ansible`, app containers by Coolify — say which, so a future session
  doesn't hand-edit a box that Ansible will revert.
- **Guardrails** are where real damage gets prevented — e.g. *"Do not put
  service-role keys in browser app repos, GitHub Actions logs, or committed .env
  files. Frontends use anon keys only. For migrations use the separate item
  'Supabase DB Password - shared POP database'."* Cross-reference sibling entries
  by exact title so the reader can jump straight there.
- **Provenance** with an absolute date explains why it exists and how stale it
  might be. "Recently" or "last session" is meaningless to a stranger.

For a **pure information entry**, use the same shape minus the concealed fields:
what it is, the identifiers, what a future session would use it for, ownership,
and provenance. The "use cases" block matters most here — an info note nobody can
tell the purpose of is the fastest thing in the vault to rot.

Put non-secret values in plaintext `text` fields (they're readable via
`item_get` without `reveal`, so future sessions can orient without exposing
anything). Put every actual secret in a `concealed` field. Name fields after the
env var they populate — `SUPABASE_SERVICE_ROLE_KEY`, not `key2` — so a session
rebuilding a `.env` can map them mechanically.

## Worked example

```
note_create(
  vaultId: "<from vault_list>",
  title: "Coldlion ERP API Key - x5.coldlion.com (production, read-only)",
  tags: ["coldlion", "erp", "api", "production", "read-only", "ai-session"],
  notes: """
Read-only API key for the Coldlion ERP REST API at x5.coldlion.com, used to pull
order and inventory data into POP reporting.

Base URL: https://x5.coldlion.com/api/v5
Account: integrations@popcre.com
Auth header: Authorization: Bearer <COLDLION_API_KEY>

Use cases for future AI sessions:
- Pull order/inventory data when reconciling ERP figures against PIM.
- Probe ERP endpoints while debugging a sync mismatch.
- Rebuild the sync job's env without asking Albert for the key.

Used by the ERP sync job in u2giants/poppim-web (services/coldlion/). Not
consumed by any browser frontend.

This key is read-only and cannot write to the ERP — if a task needs writes, stop
and ask Albert rather than hunting for a stronger credential. Do not commit it to
.env files or echo it in CI logs; use op:// references instead.

Created during the 2026-07-15 ERP sync session because the key was living only in
a local .env and would have been lost on machine rebuild.
""",
  fields: [
    { idOrTitle: "COLDLION_BASE_URL", type: "text", value: "https://x5.coldlion.com/api/v5" },
    { idOrTitle: "COLDLION_ACCOUNT", type: "text", value: "integrations@popcre.com" },
    { idOrTitle: "COLDLION_API_KEY", type: "concealed", value: "<the key>" }
  ]
)
```

## Before you report it done

Re-read the notes as the stranger: could they find this entry by searching for
the service, and then use it with no further questions? If the notes don't say
what it unlocks, where it's used, or what not to do with it, expand them. Too
much detail costs a few seconds of reading; too little costs Albert a session.

Then confirm with `item_get` (no `reveal`) that title, tags, notes, and field
names landed, and report the title, item ID, and `op://vibe_coding/<title>/<field>`
reference. In sweep mode, report one line per secret — including the ones you
found already stored, so Albert can see the sweep actually looked.

When a secret came from a file on disk (a local `.env`, a scratch file), say so
and recommend replacing it with an `op://` reference — the vault copy doesn't
help if the plaintext original is still sitting there waiting to be committed.
