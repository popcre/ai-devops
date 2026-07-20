# Credential exposure response — July 2026

## Purpose and scope

This report records the production credential rotations completed after secrets
were found in the public history of `u2giants/synology-monitor` and in session
transcripts that were temporarily present in the public history of
`u2giants/ai-devops`. It intentionally contains no credential values or hashes.

The transcript archive now lives in the private repository
`u2giants/ai-devops-transcripts`, mounted in this repository as the
`transcripts/` submodule. Historical public exposure must still be treated as a
compromise even after files are removed from a branch or repository history.

## Completed rotations

All six originally confirmed-live values were rotated in three atomic groups.
Every new value was generated and stored in 1Password before it was propagated.
Runtime updates consumed protected `op://` references or injected process
environment; values and hashes were never placed in chat, command arguments,
reports, or commits.

### Edge1 — completed 2026-07-17

Rotated together:

- `NAS_EDGE1_API_SECRET`
- `NAS_EDGE1_API_SIGNING_KEY`

Updated consumers:

- 1Password vault `vibe_coding`, item `nas-monitor-secrets`
- Coolify application `nas-monitor-web`, production and preview rows
- Coolify application `nas-mcp`, production and preview rows
- Edge1 NAS agent environment at
  `/volume1/docker/synology-monitor-agent/.env`
- Standalone container `synology-monitor-relay-public`

Verification evidence:

- New bearer returned HTTP 200; the leaked bearer returned HTTP 401.
- New signing key returned HTTP 200 on a harmless nonexistent-service check;
  the leaked signing key returned HTTP 403.
- `nas-monitor-web` deployment `na0q18o4r78l5xperoi5suqj` finished.
- `nas-mcp` deployment `zkxlo1ci57239szo7dwdx1gn` finished.
- Edge1, relay, and `nas-mcp` health checks returned HTTP 200.
- All three runtime consumers matched the canonical concealed 1Password fields.
- The NAS environment was corrected from world-readable mode 555 to
  `root:root` mode 600.
- Temporary values, files, backups, containers, and authorization were removed.

Access lesson: a temporary authorization of the existing `916-alien` public key
for direct root SSH was used and then removed. No DSM Scheduled Task was ever
created; the authorization was installed manually in an existing SSH session.
The safer retained state is direct key login for `ahazan` and `ai`, with direct
root SSH disabled and administrative work performed through `sudo`.

### Edge2 — completed 2026-07-19

Rotated together:

- `NAS_EDGE2_API_SECRET`
- `NAS_EDGE2_API_SIGNING_KEY`

Updated the same classes of consumer as Edge1: canonical 1Password fields, eight
Coolify production/preview rows across `nas-monitor-web` and `nas-mcp`, the Edge2
NAS environment, and the standalone relay.

Verification evidence:

- New bearer returned HTTP 200; the leaked bearer returned HTTP 401.
- New signing key returned HTTP 200 on a harmless nonexistent-package status
  check; the leaked signing key returned HTTP 403.
- Both Coolify deployments finished and `nas-mcp` was healthy.
- Relay health, catalog, and Edge2 preview returned HTTP 200.
- All eight Coolify rows and the relay matched canonical concealed 1Password
  fields.
- Edge2 NAS environment is now `root:root` mode 600.
- Temporary values, rollback backup, and secret-bearing files were removed.

Failure and recovery notes:

- The stored Edge2 sudo password was stale. The NAS file update had initially
  succeeded only because an existing sudo ticket was cached. Albert manually ran
  one constrained `docker-compose ... --no-deps --force-recreate nas-api`
  command and entered the current password locally; no password entered chat.
- The first relay replacement used a malformed empty environment file and
  restart-looped with a missing-variable error. Promotion stopped. The relay was
  rebuilt from its protected pre-cutover Docker inspection snapshot, replacing
  only the Edge2 pair, and returned to HTTP 200 before work continued.
- A signing-key test script had Windows line-ending/path problems. The gate was
  rerun successfully with the proven harmless test; it was not waived.

### Relay authentication — completed 2026-07-19

Rotated together:

- `RELAY_BEARER_TOKEN`
- `RELAY_ADMIN_SECRET`

The verified consumer is the standalone container
`synology-monitor-relay-public`; there are no Coolify rows for these two values.
`https://mon.designflow.app/` is the live Synology Monitor application. It was
originally developed through Lovable but is not currently managed through an
active Lovable project or separate secret store.

Verification evidence:

- Relay health returned HTTP 200.
- The new bearer returned HTTP 200 for `/catalog` and a read-only NAS preview.
- The leaked bearer returned HTTP 401.
- Both live relay values exactly matched their canonical concealed 1Password
  fields after promotion.
- No non-mutating admin-only endpoint exists. The admin secret was therefore
  verified by protected equality between the canonical 1Password reference and
  live runtime; no write operation was executed merely to test it.
- Temporary generator items were archived, `_next` fields removed, and the old
  secret-bearing rollback container removed. Item history remains the emergency
  rollback source.

## Deliberately untouched credentials

- `nas-mcp`'s `MCP_BEARER_TOKEN` is a separate credential and was not part of
  these three rotations.
- Edge1 values were not changed during Edge2 or relay rotations.
- Edge2 values were not changed during the relay authentication rotation.
- The already-rotated Synology Monitor Supabase service-role key was not changed.

## Remaining incident work

The three known rotation groups are complete, but the incident is not closed.
The private transcript archive must be scanned for the full blast radius. Each
credential-shaped finding must be classified and compared with its live source
without printing values or hashes. The audit must explicitly include the leaked
OpenRouter key and the `popdam` NAS SSH password. The password must not be tested
by authenticating; mark it unknown unless a safe comparison source exists and
recommend precautionary reset when necessary.

Final audit artifacts belong under `/home/ai/rotation/` on `hetz`. GitHub Support
requests for sensitive-data cleanup remain appropriate for unreachable public
commit objects in `u2giants/ai-devops` and the still-leaking history of
`u2giants/synology-monitor`. Rotation remains the primary remediation.

## Operational guardrails

- Never print a secret or its hash.
- Create replacement credentials in 1Password first.
- Preserve canonical values until every new-value gate passes.
- Rotate co-deployed pairs atomically.
- Use 1Password item history only for emergency rollback after promotion.
- Keep direct root SSH disabled; use named users and `sudo`.
- Never use the stale repository file `apps/relay/.env.runtime` as a live
  deployment source. Reconstruct relay configuration from the running container
  or a protected Docker inspection snapshot.
