# Memory incident containment evidence

Generated: 2026-08-22T00:13Z

## Scheduled writers

| Machine | Containment | Preservation evidence |
|---|---|---|
| `albt16` | Windows task `ai-memory-sync` disabled | owner-only incident backup `memory-sync-20260821T233744Z`; 117 files; 240,605 bytes; manifest SHA-256 `1E81B26FC82CD3366F21807506059116CC9B54E517462056D3EF5F10128596C0` |
| `al8960ofc` | Windows task `ai-memory-sync` disabled | owner-only incident backup `memory-sync-20260821T233826Z`; 136 files; 241,624 bytes; manifest SHA-256 `A2DACA173E42F9010EE8F53D24A4825C273ADCB5D57EEB6754D0E690536BB7BD` |
| `hetz` | Ansible PR #9 removed the exact cron entry | owner-only backup `memory-sync-20260821T234500Z`; mode `0700`, owner `ai:ai`, 156 files and 156 manifest entries |
| `edge-dev` | Direct administration was denied; public child command at commit `7f9b494da9222577d46d8080d99703737827db61` blocks uploads before copying | the last edge commit remains `c97262261e9cfc46745c31bc77c98d0af4b2713c`; its published state is included in the protected union |

Ansible production evidence:

- PR: `u2giants/ansible#9`
- merge: `2a1483fb319acf998796adea906830fbc9fe2d5b`
- serialized production apply: run `32538162506`
- tagged idempotency apply: run `32538279572`, `changed=0`, `failed=0`
- live read-only verification: `CRON_ABSENT`, backup mode `700`, 156 files

The former public-memory sequence ended with:

1. `7a1c8829d344b5a26bd7ea29b563c5dfbc2bd958` - `al8960ofc`
2. `aff60860bef074b4269145aa6534d915ce83b757` - `hetz`
3. `c97262261e9cfc46745c31bc77c98d0af4b2713c` - `edge-dev`

At `2026-08-21T20:31:15-04:00`, a fresh `origin/main` fetch showed no later
memory-sync commit. That is 60 minutes 13 seconds after the last former writer,
proving two full former 30-minute schedule intervals remained contained.

No memory file was deleted during capture. Protected source copies are outside
the public checkout with inheritance removed and access restricted to the owner
and Windows SYSTEM.

## Private union

- Repository: `u2giants/ai-devops-memory`
- GitHub API proof: `private=true`, `visibility=private`, default branch `main`
- Initial union: 29 source project directories and 467 facts; zero detector hits
- Credential-reference remediation: one SSH-passphrase memory was tombstoned and
  removed without opening or displaying its contents. The protected incident
  sources remain the recovery copy pending the coordinated public-history purge.
- Current private head: `2765c34192a74a4a106998ef5f9d7f792bcf7263`
- Coverage health: 24 non-empty projects, 420 facts, zero missing indexes, zero
  missing index entries, zero broken index targets
- Empty but required indexes exist for `directus`, `plane`, and `twenty`.

## Behavioral gates

- `tests/test-build-private-memory-hub.ps1`: union, tombstone, orphan-index, and
  secret-pattern gates pass.
- `tests/test-ai-sync-memory-public-containment.sh`: canonical public upload is
  blocked nonzero and a compatibility pull preserves local and hub index entries.
- `tests/test-ai-memory-sync.sh`: private visibility fixture, two-sided union,
  offline failure, rejected-push preservation/retry, same-name conflict retention,
  orphan indexing, tombstone deletion, and duplicate-lock rejection pass.
- `tests/test-memory-sync-scheduled-task.ps1`: schedule requires explicit opt-in,
  reports the real child exit status, prevents overlap, and remains disabled by
  default.
- Live `albt16` private sync pushed the private hub and the exact head passed
  `ai-memory-health --hub-only --coverage-only` with zero findings.
