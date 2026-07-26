---
name: sandbox-env-quirks
description: Sandbox gotchas — a root process periodically breaks .git ownership; Go is not preinstalled.
metadata: 
  node_type: memory
  type: project
  originSessionId: 9f3e683d-d8db-47ad-bc6b-1954ca90287e
---

Two recurring environment issues in the `/worksp/monitor/app` sandbox (the git repo
root is `app/`, not `/worksp/monitor`).

**1. A root process periodically corrupts git ownership.** `.git/index` and some
loose objects/refs under `.git` get rewritten as `root:root` mode 600, so the `ai`
user gets "index file open failed: Permission denied", "your current branch appears
to be broken", or `refs/heads/main` reading as all-zeros. The commits are intact —
it is purely an ownership/readability problem. Also seen on source files (e.g.
`validator_test.go` was root-owned 600). Fix: `sudo chown -R ai:ai .git` (and chown
any root-owned source file). `ai` has passwordless sudo. Saw it 2026-06-02/03;
likely a root-run cron/agent touching the repo — worth tracking down at the source.

**2. Go is not preinstalled** (repo needs `go 1.23`). Install:
`curl -sLO https://go.dev/dl/<ver>.linux-amd64.tar.gz` →
`sudo tar -C /usr/local -xzf …` → `sudo ln -sf /usr/local/go/bin/go /usr/local/bin/go`.
Build with `go build -buildvcs=false ./...` (VCS stamping fails on the ownership
quirk above). May not persist across sandbox resets.

**Why:** these silently block builds, tests, and commits and look like code/repo
corruption when they are just file ownership. **How to apply:** if git or `go build`
fails oddly here, check ownership first before assuming real breakage. Related:
[[call-limit-folklore]].
