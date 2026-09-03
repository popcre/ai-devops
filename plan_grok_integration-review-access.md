# IMPLEMENTATION PLAN — isolated Grok integration-review access

Tracking issue: [popcre/ai-devops#249](https://github.com/popcre/ai-devops/issues/249)

Planning handoff: [`HANDOFF.d/2026-09-03T2143Z-edge-dev-codex-grok-integration-review.md`](HANDOFF.d/2026-09-03T2143Z-edge-dev-codex-grok-integration-review.md)

> Planning record only. No reviewer behavior, machine configuration, installation,
> sandbox, proxy, or live/network canary was changed or run while writing this plan.

## STATUS

| Phase | Deliverable | Status | Evidence required before changing status |
|---|---|---|---|
| 0 | Reconfirm source, provider, platform, and issue baseline | ⬜ open | A dated baseline under `tests/verification/grok-integration-review/` containing exact source SHA, installed Grok version/help/inspect output, platform probes, and dirty-tree exclusions |
| 1 | Define the integration-review contract and policy schema | ⬜ open | Schema fixtures and offline policy tests prove fail-closed parsing, locked defaults, and approval-reviewer non-regression |
| 2 | Build the disposable Linux execution boundary | ⬜ open | Hostile offline tests prove source read-only, writable areas disposable, no ambient identity/configuration, resource limits, and reliable destruction |
| 3 | Add the deny-by-default fetch/endpoint broker | ⬜ open | Workload remains offline; structured broker DNS/TLS/redirect/private-range tests prove only declared operations, destinations, and volume are reachable |
| 4 | Add the separate Grok integration-review wrapper | ⬜ open | Wrapper tests prove distinct naming/state, exact-head packet binding, mediated shell, cited research, lifecycle truth, and no change to `ai-grok-review` |
| 5 | Add evidence, sanitization, tamper, and rollback controls | ⬜ open | Golden evidence fixtures prove command/result sanitization, digests, prohibited-write detection, cleanup attestation, and fail-closed uncertainty |
| 6 | Qualify safely on Linux and from Windows | ⬜ open | Owner-approved canary record proves allowed research/build/endpoint behavior and denied DNS/HTTP/private/metadata/proxy bypasses without contacting production |
| 7 | Complete independent review, full tests, CI, install verification, and landing | ⬜ open | Exact-head APPROVE, complete test artifacts, green CI run, installed/source hashes, both-tier smoke proof, pushed `origin/main`, and issue update |

**Fresh-session start:** Phase 0. Re-read the remaining phases before each phase
and update this STATUS table when evidence changes. Nothing below is implemented.

---

## 1. The ultimate goal — what we are actually trying to achieve

Albert must be able to ask Grok for a deeper review that really runs builds,
tests, dependency checks, documentation research, and specifically approved
endpoint checks, while a malicious dependency, test, repository, or model tool
call still cannot reach the live checkout, credentials, private networks,
production systems, or an uncontrolled recipient.

The existing fail-closed approval reviewer remains the normal governance gate and
remains byte-for-byte behaviorally unchanged. A separately named
**integration review** is an additional, explicit tier for evidence that static
inspection cannot provide. It is not a more permissive mode of the approval
reviewer and cannot substitute for its exact-head independent verdict.

Containment must be enforced outside prompts and Grok command rules. Source is
verified, mounted read-only, copied only into disposable writable storage for
tools that require in-tree output, and checked again afterward. Network access is
deny-by-default, brokered, public-destination-only, bounded, and recorded.
Uncertainty is failure. The environment is destroyed after evidence export.

**If a step conflicts with this goal, the goal wins — stop and flag it.** Never
weaken, remove, bypass, or silently replace either reviewer tier to make the work
easier.

## 2. What this application is

`popcre/ai-devops` (the current Git remote; historical documents also call the
toolkit `u2giants/ai-devops`) is Albert Hazan's public, cross-platform recovery
toolkit for a multi-model development workflow. It contains Bash and PowerShell
wrappers, policy/configuration, skills, documentation, and offline tests. It has
no application deployment, database, or production web service. Finished source
lands directly on `main`, is verified by GitHub Actions, and is installed by the
repository's lifecycle scripts.

The affected existing path is `bin/ai-grok-review`, a persistent named-session
approval reviewer. At the planning baseline, working-tree line references are:

- `bin/ai-grok-review:1-20`: the only supported review entry point; model,
  permissions, turn bound, completion, and session bookkeeping are wrapper-owned.
- `bin/ai-grok-review:66-87`: frozen `grok-4.6` read-only policy denies Edit,
  Bash, and all MCPs; removes MCP meta-tools/agents; disables subagents, web
  search, memory, and Claude/Cursor/Codex imports.
- `bin/ai-grok-review:89-93`: bounded turns, wait, isolation inspection, polling,
  and heartbeat controls.
- `bin/ai-grok-review:162-177` (`review_boundary`, `release_boundary`): a private
  self-contained snapshot prevents the live checkout moving under a review.
- `bin/ai-grok-review:196-231` (`prepare_review`): derives HEAD from Git, checks
  caller assertions, builds the evidence packet, and records its SHA-256.
- `bin/ai-grok-review:737-910` (`run_turn`): owns process-tree supervision,
  neutral homes, the single same-inode Grok authentication link, isolation
  inspection, and provider launch.
- `bin/ai-grok-review:997-1050` (`extract_answer`, `build_prompt`): preserves
  findings and the terminal governed verdict contract.
- `bin/ai-grok-review:1197-1365` (`cmd_new`, `cmd_ask`): locks exact work,
  refreshes packets for changed heads, records session metadata, and preserves
  remote uncertainty.

Related current files:

- `skills/shared/grok-cli/SKILL.md:1-146` tells both clients to use the wrapper,
  preserve named sessions, read cost/result evidence, and never broaden the
  approval reviewer's permissions.
- `skills/shared/grok-cli/SKILL.md:192-226` states that Windows cannot claim
  native Grok sandbox protection and explains private review snapshots.
- `tests/test-ai-grok-review.sh:380-418` makes the frozen permission and isolation
  contract executable; `:685-753` covers snapshot and evidence-packet lifecycle.
- `bin/ai-review-sandbox` creates/removes private snapshots; it is not presently
  a hostile-code execution sandbox and must not be renamed or represented as one.
- `bin/ai-review-packet` produces exact-source evidence packets.
- `bin/ai-process-supervisor` owns bounded process-tree termination on Windows and
  POSIX systems.
- `docs/reviewer-issues.md:1-94` defines truthful incident evidence and Grok lock
  scope.
- `plan_ai-grok-review.md`, `plan_grok_reviewer_runtime_repair.md`, and
  `plan_grok-review-concurrency-cancellation-observability.md` preserve why the
  approval path is fixed, exact-head, bounded, visible, and fail-closed.
- `plan_reviewer-cache-efficiency.md` preserves unconditional snapshot refresh;
  caching must never trade away evidence integrity.

GitHub issue #249 tracks this new work. Open issues #172, #177, #188, and #218
concern existing Grok runner/runtime behavior and remain separate; implementation
must re-resolve them before editing overlapping code rather than assuming this
plan supersedes them.

## 3. What triggered this work

Static read-only review cannot prove that code compiles, tests pass, package
metadata resolves, or a declared public endpoint behaves as documented. Giving
the current approval reviewer Bash or ordinary internet access would destroy the
assurance its fail-closed boundary provides. The requested business capability
therefore needs a separate tier whose stronger tools operate only inside a
stronger external containment boundary.

The 2026-09-03 confirmed provider baseline is Grok CLI
`1.0.5 (5115b46bc9) [stable]` on EDGE-DEV. `grok --help` confirms headless tool
filtering, permission modes, `--disable-web-search`, `--no-subagents`, custom
agents, and `--sandbox`. The official Grok Build documentation confirms:

- shell, `web_search`, and `web_fetch` exist and can be selected or removed;
- allow/deny rules govern model requests but unmatched commands can fall through
  unless `dontAsk` or an enforcing hook is used;
- hooks fail open when missing, crashing, or timing out;
- prompts, tool allowlists, permission rules, and hooks are therefore defense in
  depth, not the containment boundary;
- Grok's OS sandbox is off by default and is kernel-enforced only on Linux
  (Landlock/bubblewrap/seccomp) and macOS (Seatbelt); Windows is unsupported;
- on Linux `restrict_network` blocks child-process network, but Grok's in-process
  LLM, web-search, and web-fetch traffic remains reachable;
- built-in profiles can warn and continue if enforcement is unavailable, while
  an explicit custom profile with required deny bindings can fail closed;
- shell environment inheritance defaults are permissive unless explicitly
  restricted; persistent shell startup exports can evade later filtering.

Primary references, to be pinned to a reviewed upstream commit during Phase 0:

- [Grok Build CLI README](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-shell/README.md)
- [Grok sandbox documentation](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/18-sandbox.md)
- [Grok permissions and safety](https://github.com/xai-org/grok-build/blob/main/crates/codegen/xai-grok-pager/docs/user-guide/22-permissions-and-safety.md)

No shell/network capability or canary was exercised during planning.

## 4. Scope — in and out

### In scope

- A new, unmistakably separate command, proposed as
  `bin/ai-grok-integration-review`.
- A declarative, reviewable per-run integration policy and strict schema.
- A disposable Linux execution boundary invoked locally on Linux and through a
  broker from Windows.
- Read-only exact-source input plus a digest-identical disposable work copy.
- Build/cache/temp storage that is unique per run and deleted afterward.
- A dedicated structured fetch/endpoint broker enforcing declared domains,
  ports, methods/paths, resolved addresses, redirects, byte/request/time limits,
  and private-address denial. The workload shell has no raw network route.
- Grok's separate cited `web_search` research path. `web_fetch` stays absent;
  enabling it requires an independently enforced controller network boundary
  that passes the broker tests, and provider domain rules never enable it.
- Sanitized command, result, source-identity, network-decision, resource, write-
  audit, cleanup, and verdict evidence.
- Windows and Linux launch/installation/test behavior.
- Offline hostile tests and narrowly authorized live qualification canaries.
- Documentation and installation updates needed to operate both tiers.

### NOT in this plan

- Any change to the permissions, prompt prefix, model pin, session format,
  result rules, or ordinary behavior of `bin/ai-grok-review`.
- Giving the integration tier the live checkout as its working directory.
- Mounting the host Docker/Podman socket or a broad host directory.
- Production, internal, VPN, Tailscale, LAN, localhost, cloud-control-plane,
  database, SSH, browser, MCP, or authenticated application access.
- General-purpose browsing, email, chat, GitHub write access, package publishing,
  deploys, database writes, commits, pushes, or merges.
- Automatic approval of a previously unseen endpoint or dependency registry.
- Treating successful container startup, HTTP 200, or provider completion as
  proof of containment or business correctness.
- Replacing `ai-grok-review`, weakening it, or removing Grok because secure
  integration review is difficult.

## 5. Current state of the code

### Confirmed working baseline

The current approval reviewer is structurally read-only and provider-specific.
It provides a private snapshot, exact-head evidence packet, fixed model and tool
policy, neutral home/config roots, disabled MCPs/subagents/imports/web, bounded
process ownership, named continuity, lock/idempotency protections, result JSON
validation, retained uncertainty, usage reporting, and governed verdict output.
Those controls are protected by the current wrapper header and offline suite.

The current private snapshot is source-stability isolation, not execution
containment: it has its own `.git` and prevents movement of the live checkout,
but Grok is deliberately denied Bash. The existing snapshot helper neither
creates a network namespace nor supplies resource quotas. The integration tier
must consume its output as read-only input or introduce a narrowly separate
snapshot mode; it must not silently reinterpret existing behavior.

### Provider and platform capability matrix

| Capability | Grok 1.0.5 / Linux | Grok 1.0.5 / Windows | Consequence |
|---|---|---|---|
| Select shell/web tools | Yes | Yes | Provider flags can reduce surface, but are not containment |
| Native filesystem sandbox | Landlock/bubblewrap when supported | No documented enforcement | Windows must dispatch to an external Linux boundary |
| Block shell child networking | Linux seccomp with `restrict_network` | No | Keep the integration workload offline; use structured controller broker operations |
| Keep in-process cited web search | Yes, outside child-network block | Yes | Useful for research, but citations/results must be retained separately |
| Deny/allow command rules | Yes | Yes | Defense in depth only; parsing and hooks are not a security perimeter |
| Environment filtering | Yes | Yes | Must still launch from an empty environment and neutral homes |
| External VM/container/proxy | Not provided as a complete policy | Not provided | Repository must integrate or broker a real execution boundary |

### Planning checkout state

Planning began on `main` at `bffec57fb81ae02362b54bc48831044c5abec37a`.
The shared checkout already contained unrelated modified and untracked files,
including concurrent changes to `AGENTS.md`, `bin/ai-grok-review`,
`bin/ai-review-sandbox`, existing reviewer plans/tests, and other handoffs. This
plan uses the inspected working-tree line numbers above but owns none of those
changes. Implementation must start from freshly resolved `origin/main`, inspect
open work/claims/issues, and record its own exclusions before editing.

### Untouched / not implemented

There is no `ai-grok-integration-review`, integration policy schema, hardened
execution image, egress broker, broker client, integration evidence format,
hostile containment suite, or installation entry today. No live qualification
has occurred. Every STATUS phase remains open.

## 6. Key findings and root cause

1. **The missing capability is not merely a Grok flag.** Enabling Bash in the
   current host process would give package scripts and tests the host user's real
   filesystem and network authority.
2. **Grok can request the tools but cannot enforce the full goal on Windows.**
   Windows lacks the documented Grok OS sandbox; external Linux containment is a
   platform requirement, not an optional hardening step.
3. **Grok's Linux sandbox alone does not implement allowlisted shell egress.**
   It can block child networking, while in-process web tools remain connected;
   it does not provide a domain-aware, redirect-safe, volume-bounded package and
   endpoint gateway.
4. **Domain checks require address checks.** DNS rebinding, CNAMEs, redirects,
   proxy environment variables, alternate IP forms, IPv6, and direct sockets can
   turn a seemingly public hostname into localhost, LAN, metadata, or internal
   access unless resolution and routing are enforced outside the workload.
5. **Build tools need writes even when source input is immutable.** The safe
   pattern is read-only source mount -> verify digest -> copy into a disposable
   writable work volume -> verify copied digest before execution -> retain only
   sanitized evidence/artifacts -> prove the original mount unchanged -> destroy.
6. **Authentication must not enter the workload.** The Grok model connection
   itself requires authentication, but the shell-visible environment must not
   receive host tokens or auth stores. The architecture needs a trusted launcher
   or credential broker that makes the provider connection without placing a
   reusable credential in the review filesystem/environment. If the installed
   Grok CLI cannot support that split, the whole CLI must run in a separately
   trusted control plane and expose only a remote sandbox shell tool to the model.
7. **Cited research and dependency/endpoint retrieval are different risks.**
   Prefer Grok's cited search tool for documentation. Keep the shell workload
   offline: a structured broker prefetches approved dependency artifacts into a
   disposable cache and performs narrow approved endpoint requests. This avoids
   turning a general shell or TLS CONNECT tunnel into an exfiltration channel.
8. **A verdict remains independent only when exact-source protections survive.**
   Integration evidence supplements the approval verdict; it never becomes a
   self-approval shortcut.

Root cause: the present wrapper was intentionally optimized for safe static
review. Meaningful execution requires a new trust architecture, not permission
broadening inside that wrapper.

## 7. Approaches considered and REJECTED

1. **Enable `--allow Bash` on `ai-grok-review`.** Rejected: changes the locked
   approval tier and exposes host authority.
2. **Trust the prompt to forbid bad commands.** Rejected: prompts are policy
   guidance, not containment; malicious repository text or dependencies can
   redirect behavior.
3. **Use a command allowlist or Grok hook as the primary guard.** Rejected:
   shell grammar, interpreters, package managers, test runners, Git helpers, and
   command substitution defeat semantic allowlists; official hooks fail open.
4. **Run Grok's Windows process under `--sandbox`.** Rejected: Grok 1.0.5 does
   not document Windows OS enforcement.
5. **Use only Grok `strict` on Linux.** Rejected: built-in failure can warn and
   continue, strict permits CWD writes, and its child network control is block/
   allow rather than destination allowlisting. A custom fail-closed profile is
   defense in depth inside a stronger disposable boundary.
6. **Pass Docker/Podman socket into the reviewer.** Rejected: the socket is
   normally root-equivalent host control.
7. **Rely only on proxy environment variables.** Rejected: malicious code can
   unset them, open direct sockets, use DNS as a channel, or call an alternate
   proxy. The workload namespace must have no network path; only structured
   controller broker operations may retrieve declared data.
8. **Allow arbitrary DNS but filter HTTP.** Rejected: DNS itself can exfiltrate
   encoded source and can resolve allowed names to prohibited addresses.
9. **Allow a package registry wildcard or all CDN/storage hosts forever.**
   Rejected: registry dependency graphs and redirects create an uncontrolled
   outbound surface. Resolve and review a per-ecosystem destination set, pin
   lockfiles, and fail when a new destination is required.
10. **Mount the source writable and diff afterward.** Rejected: detection after
    mutation does not preserve the live checkout and cleanup may be uncertain.
11. **Copy the user's home/auth stores and sanitize afterward.** Rejected:
    exposure is irreversible once a command can read or transmit a credential.
12. **Put the Grok auth file inside the shell-visible container.** Rejected:
    Bash can read it. Use a trusted control plane/credential broker or stop.
13. **Permit GitHub CLI or restore Git remotes.** Rejected: credentials and
    outbound write channels are unnecessary; local Git may inspect the remote-
    less disposable repository only.
14. **Use WSL2 alone as the Windows security boundary.** Rejected: default WSL
    exposes Windows mounts and host networking. It is acceptable only inside a
    demonstrably locked-down disposable VM/broker design with those paths and
    routes absent, not as an assumption.
15. **Reuse persistent writable caches across repositories.** Rejected: enables
    cross-run data leakage and poisoned artifacts. Optional immutable, content-
    addressed seed layers may be considered later; every run's writable cache is
    unique and destroyed.
16. **Let integration evidence replace approval review.** Rejected: execution by
    a capable agent is not an independent fail-closed approval verdict.
17. **Run only a deterministic controller-declared command harness and give Grok
    no model-callable execution tool.** Rejected as the final design because the
    requested integration reviewer must investigate failures, choose follow-up
    diagnostics, and test hypotheses; a fixed preflight report cannot provide
    that deeper review. Adopt its safe half: policy declares permitted entry
    commands and a deterministic preflight is the first Phase 4 milestone.
18. **Give the workload transparent HTTPS/CONNECT egress.** Rejected: a generic
    encrypted tunnel prevents method/path/redirect/content validation and allows
    uploads or query-string exfiltration even to an approved host. Keep the shell
    offline; expose structured dependency-fetch and endpoint-check operations.

## 8. Design decisions already made, and their reasoning

### LOCKED — do not relitigate (Albert Hazan, 2026-09-03)

- Preserve `ai-grok-review` unchanged as the fail-closed approval reviewer.
- Add a separately named integration-review tier; never add a hidden switch to
  the approval command.
- Use an isolated disposable snapshot/container/VM.
- Mount source read-only and grant writes only to disposable build/cache/temp.
- Remove Git remotes; inherit no ambient secrets, tokens, auth stores, SSH
  agents, browser profiles, MCPs, or user configuration.
- Deny egress by default and allow only declared domains.
- Block localhost, all private/link-local/multicast/reserved ranges, cloud
  metadata, production/internal destinations unless separately authorized.
- Prefer separately cited web search over general shell internet.
- Bound time, process count, CPU, memory, disk, output, requests, bytes, and
  network time.
- Record sanitized commands/results, verify source digests, detect prohibited
  writes, destroy reliably, and fail closed on uncertainty.
- Preserve exact-head, evidence-packet, lifecycle, and verdict protections.
- Prompts and command allowlists are never represented as containment.
- Difficulty is not permission to weaken or remove the reviewer.

### Provider-specific recommendation (2026-09-03)

Use a **trusted integration controller plus an untrusted disposable Linux
workload and dedicated structured fetch/endpoint broker**:

1. The controller owns Grok authentication, exact-head packet/session/lifecycle
   state, policy validation, evidence export, and teardown decisions.
2. The untrusted workload receives no provider credential. It receives a
   digest-verified disposable copy of the read-only source and a minimal pinned
   toolchain. Its only callable capability is a broker-defined shell execution
   interface with resource limits.
3. The workload shell has no network route. Its per-run bridge exposes only
   bounded execution plus structured `dependency_fetch` and `endpoint_check`;
   the broker performs DNS and TLS outside the workload, validates every hop,
   writes approved artifacts/results into the disposable exchange volume, and
   accepts no arbitrary headers, bodies, proxying, or tunnels.
4. Grok's native `web_search` supplies cited research through the already trusted
   xAI model service and records each query/citation. `web_fetch` stays absent
   unless an independently enforced controller network boundary passes the same
   broker tests; provider tool rules alone cannot authorize it.
5. Prefer a rootless OCI container on a dedicated, non-production Linux runner
   when kernel/cgroup/network controls pass qualification. Escalate to a
   disposable microVM if container isolation or credential separation cannot be
   proven. Do not emulate this locally on Windows.

This is the fewest-moving-parts safe Grok design because it keeps the proven
review lifecycle/controller and adds one provider-neutral sandbox boundary plus
one egress decision point. It does not require Grok to enforce controls it lacks.

### OPEN — resolve by the named gates, not by guess

1. **Grok-to-sandbox tool bridge.** First test whether Grok 1.0.5 can use a
   single controller-owned local MCP/tool whose server exposes only
   `sandbox_exec` and cannot access host data. If MCP transport necessarily
   exposes credentials/config or weakens transcript/lifecycle guarantees, use a
   controller-mediated agent profile/tool adapter. Gate: hostile tool-discovery
   tests show no Bash-on-controller, general MCP, or alternate integration tool.
2. **Provider credential separation.** Determine from pinned upstream source and
   a no-secret fixture whether Grok auth can remain solely in the controller
   while model tool calls execute in the workload. Gate: workload `/proc`, env,
   mounts, filesystem, and command output contain no reusable credential. If not,
   this is a platform gap requiring a separate trusted Grok control plane or
   vendor-supported credential broker; do not ship an auth-mounted container.
3. **Container versus microVM.** Select rootless container only if the actual
   runner proves user namespaces, read-only mounts, seccomp, capabilities drop,
   cgroup v2 quotas, network namespace isolation, and kill/cleanup. Otherwise use
   a disposable microVM/hosted sandbox with equivalent attestations.
4. **Egress implementation.** Prefer maintained HTTP/TLS client libraries plus a
   small structured fail-closed policy adapter over a transparent proxy or custom
   packet parser. It accepts operations, not arbitrary URLs/headers/bodies, and
   validates DNS and every redirect/hop. Select only after bypass tests pass.
5. **Artifact retention.** Default to sanitized text evidence and explicitly
   named build reports. Binary artifact retention is opt-in by type/size and
   malware-scanned outside the live checkout.
6. **Safe live endpoints/domains.** Owner approval is required for the exact
   public canary destinations and any paid hosted sandbox. No production or
   internal endpoint is implied by this plan.
7. **Windows dispatch and controller identity.** Recommend mutually authenticated
   HTTPS to a dedicated non-production Linux controller, with server/client keys
   scoped only to submit/status/cancel/evidence for digest-bound runs, stored in
   1Password and provisioned through the existing secret procedure. The Linux
   controller's Grok credential is a separate controller-only item and never
   reaches the workload. Owner must approve the exact host, recurring cost if
   any, and secret provisioning route. Gate: mutual identity, replay, expiry,
   revocation, payload allowlist, and workload non-reach tests pass before any
   source leaves Windows.

## 9. The plan — ordered implementation phases and dependencies

### Phase 0 — reconfirm truth before design is executable

1. **Resolve current source and concurrent ownership.** In a clean isolated
   current-main worktree, record `origin/main`, HEAD, open issues #172/#177/#188/
   #218/#249, work claims, relevant OPEN handoffs, and dirty exclusions. Re-read
   `AGENTS.md`, `docs/architecture.md`, `docs/development.md`,
   `docs/deployment.md`, the headers of `bin/ai-grok-review`,
   `bin/ai-review-sandbox`, `bin/ai-review-packet`, and their tests.
   Dependency: none. **Gate:** a dated baseline artifact contains reproducible
   commands and exact SHAs; no unrelated file was changed.
2. **Pin and inspect provider capabilities.** Record installed and supported
   Linux/Windows Grok versions, `--help`, `inspect --json`, pinned official docs/
   source commit, tool IDs, MCP/agent profile behavior, custom sandbox failure
   semantics, environment policy, web-search citations, and session JSON. Do not
   expose auth data or make a paid call in this step. **Gate:** every provider
   claim in §§3/5/6 is confirmed or this plan is updated before implementation.
3. **Probe candidate host controls without untrusted networking.** On the chosen
   non-production Linux runner, verify kernel, rootless runtime, user namespaces,
   cgroup v2, seccomp, read-only mounts, network namespaces, firewall ownership,
   and reliable forced cleanup using local fixtures only. **Gate:** any missing
   mandatory primitive selects microVM/hosted isolation or blocks Phase 2.

Natural context cut: update STATUS, use `fresh-session`, and re-read Phases 1-7.

### Phase 1 — contract and policy before execution

4. **Add `config/grok-integration-review-policy.schema.json`.** Define strict
   `additionalProperties:false` fields: version, source SHA/digest, build/test
   commands, toolchain/image digest, allowed cited-research mode, dependency
   registries/coordinates/expected digests, endpoint IDs with exact domain/port/
   method/path, per-operation request/byte caps,
   runtime/CPU/memory/PID/disk/output caps, retained artifacts, and approval
   metadata. Shell egress is not representable in the schema. Defaults are no
   commands beyond declared tasks, cited search only, no dependency/endpoint
   operations, and no retained binaries. **Gate:** schema tests reject
   unknown keys, wildcards, URLs with userinfo, IP literals, Unicode confusion,
   private/reserved names, unlimited/zero bounds, and missing source identity.
5. **Add `config/grok-integration-review-policy.example.json`.** It is secret-free,
   non-production, and documents one offline build plus cited research; endpoint
   access remains disabled. **Gate:** example validates and contains no credential,
   real internal name, production URL, or broad wildcard.
6. **Define the evidence contract in `docs/grok-integration-review.md`.** Specify
   run identity, controller/workload trust split, evidence JSON/Markdown fields,
   sanitization, uncertainty states, owner authorization, incident recording,
   and why integration evidence never replaces approval. **Gate:** documentation
   maps every locked requirement to an enforcing component and test.

### Phase 2 — disposable Linux workload

7. **Add a narrowly named sandbox launcher** (proposed
   `bin/ai-integration-sandbox`) rather than changing `ai-review-sandbox` behavior.
   Functions should include `validate_host`, `prepare_source`, `create_workload`,
   `exec_bounded`, `audit_mounts`, `collect_evidence`, and `destroy_workload`.
   It must use an argv array, never shell-evaluate policy text. **Gate:** shell
   syntax/static checks and hostile argv tests prove no injection or host socket/
   device/capability exposure.
8. **Prepare exact source.** Consume a private snapshot, remove all remotes and
   credential helpers, create a canonical manifest/digest excluding only the
   generated evidence directory, mount it read-only, copy it into a unique
   writable volume, and verify tree digest/HEAD/packet digest before execution.
   Never mount the live checkout. **Gate:** mutation attempts against input fail;
   the work copy begins digest-identical; `.git/config` has no remote/helper;
   symlink, submodule, alternate-object, and path-escape fixtures fail closed.
9. **Create the workload with zero ambient authority.** Use an empty environment
   plus explicit safe variables, neutral UID/GID/home, no host namespaces,
   devices, capabilities, socket, agents, profile, config, keychain, browser,
   MCP, or user mounts; read-only root filesystem; `no-new-privileges`; pinned
   image digest; tmpfs/volumes only for work/cache/temp/output. **Gate:** hostile
   inventory tests find only declared paths/variables/processes and cannot read
   host markers, credential fixtures, kernel-dangerous interfaces, or sibling
   run data.
10. **Enforce resource ceilings.** Apply wall/CPU time, memory/swap, PID/thread,
    file descriptor, file size, writable bytes/inodes, stdout/stderr, retained
    artifact, and process-tree bounds. **Gate:** fork bomb, disk fill, output
    flood, memory pressure, background/orphan, and timeout fixtures terminate the
    full workload, retain bounded sanitized evidence, and leave no live process.
11. **Make teardown a state machine.** Record `prepared -> running -> collecting
    -> destroyed` with exact IDs; on signals/errors, revoke network first, stop
    workload, export bounded evidence, unmount/remove exact resources, and verify
    absence. Unknown ownership or cleanup failure becomes `cleanup_uncertain` and
    blocks new integration runs on that runner. **Gate:** kill-at-every-transition
    fixtures either prove destruction or retain a loud exact-resource block; no
    broad cleanup command exists.

### Phase 3 — controlled internet and research

12. **Add the structured egress policy adapter and broker** under
    `tools/grok-integration-egress/` and `config/`. Keep custom code limited to
    validation/decision/evidence and maintained DNS/HTTP/TLS libraries, not a new
    protocol stack. Normalize hostnames with
    IDNA rules, reject IP literals/userinfo/non-HTTPS except explicit local test
    fixtures, resolve through broker DNS, validate every A/AAAA/CNAME result, and
    revalidate on connect and redirects. Expose only
    `dependency_fetch(coordinate, expected_digest)` and
    `endpoint_check(policy_endpoint_id)`; accept no raw proxy request, caller
    headers/body, CONNECT, or socket forwarding. **Gate:** unit/property tests cover case,
    trailing dots, decimal/octal/hex IPs, IPv4-mapped IPv6, rebinding, CNAME loops,
    redirects, TLS SNI/Host mismatch, CONNECT, alternate ports, and parser errors.
13. **Keep the workload offline.** The workload network namespace has no external
    route, including to the broker. Only the trusted controller bridge can call
    broker operations and place bounded results in the run exchange volume.
    Direct IPv4/IPv6, UDP/TCP, raw sockets,
    alternate DNS/DoH/DoT, localhost, host gateway, RFC1918, CGNAT, link-local,
    multicast, reserved/test ranges, Unix/Windows host bridges, and cloud metadata
    are denied. Proxy variables are convenience only. **Gate:** packet-level
    fixtures prove every bypass is blocked even after unsetting environment.
14. **Enforce application-layer limits in the broker.** The broker is the
    ordinary TLS client: it validates public server certificates using its system
    trust store and never performs TLS interception. No interception CA/private
    key or client credential enters the workload. Allow only declared hosts, ports,
    methods, optional path prefixes, content types, redirects, request count,
    response/request bytes, and total network time. Strip auth/cookies and reject
    client certificates. Log decisions and sanitized metadata, not payloads or
    secrets. **Gate:** oversized/chunked/compressed responses, upload attempts,
    redirect chains, WebSocket/tunnel methods, range abuse, retry storms, and
    header smuggling fail closed.
15. **Separate cited research.** Integration Grok profile enables `web_search`
    and disables general MCP discovery/subagents/memory. `web_fetch` is absent;
    a provider domain rule alone can never enable it. Search-query text is itself
    provider-bound outbound data, so size-limit and retain it, prohibit secrets
    or raw bulk source in queries, and treat xAI as the same trusted processor
    already receiving review source—not as arbitrary internet.
    Retain query, returned citations/URLs, timestamps, and model/tool identity.
    **Gate:** a stubbed provider transcript proves research citations are retained
    and cannot silently become shell egress or an uncited factual claim.

Natural context cut: update STATUS, use `fresh-session`, and re-read Phases 4-7.

### Phase 4 — the separate Grok integration wrapper

16. **Add `bin/ai-grok-integration-review`.** Reuse shared helpers only where
    contracts are identical; do not add a mode flag to `ai-grok-review`. Proposed
    functions: `usage`, `doctor`, `validate_policy`, `prepare_integration_review`,
    `start_controller`, `run_integration_turn`, `await_integration_result`,
    `extract_integration_answer`, `show`, `list`, `delete`, and `reconcile`.
    Command/session/state/report names must contain `integration` and cannot
    collide with approval-review state. **Gate:** offline tests prove invoking one
    tier never reads, resumes, deletes, locks, or changes the other tier's state.
17. **Preserve exact-head/evidence/lifecycle/verdict protections.** Derive HEAD
    from Git; treat caller SHA only as an assertion; build/hash the packet;
    include policy/image/source/work-copy digests; lock exact work before provider
    contact; preserve remote/cleanup uncertainty; validate terminal JSON/model/
    stop reason; retain findings; require `## Verdict` last for governed use.
    Integration verdict must say it supplements, not replaces, approval.
    **Gate:** adapted exact-head, stale-continuation, duplicate-send, interrupted,
    invalid-JSON/model, no-verdict, and wrong-digest fixtures all fail closed.
18. **Expose only the mediated sandbox tools.** First run a deterministic policy-
    declared preflight in the workload and retain it as baseline evidence. If the
    chosen bridge is MCP, create
    a unique per-run endpoint/socket and authorize exactly its `sandbox_exec`,
    `sandbox_status`, `sandbox_artifact`, `dependency_fetch`, and `endpoint_check`
    tools; deny `run_terminal_cmd` on the
    controller, general MCP discovery/use, agents, memory, edits, and direct
    filesystem access outside the read-only review snapshot. Bind every request
    to run/session/policy digests. Reassert the empty environment and permitted
    argv/cwd on every `sandbox_exec`, not only at workload creation. **Gate:** fabricated tool names, replayed IDs,
    stale sessions, arbitrary paths, concurrent runs, and bridge loss fail closed.
19. **Keep approval reviewer invariant.** Add a golden argv/config/state snapshot
    around `ai-grok-review` and run its entire existing suite without modifying
    expected permissions. **Gate:** Git diff and behavior comparison show no
    change to approval reviewer source/installed hash except separately approved
    shared-helper changes proven behavior-neutral.

### Phase 5 — evidence and rollback

20. **Add `tests/test-ai-grok-integration-review.sh` and focused component tests.**
    Use fake Grok, local fake proxy/DNS, fixture images, and disposable namespaces;
    offline is default. No paid call or internet is required for the suite.
    **Gate:** every §10 case has a named passing assertion and no skips on the
    qualifying Linux runner.
21. **Create tamper-evident evidence.** Store a manifest plus SHA-256 for source,
    packet, policy, image, work copy before/after, commands (argv + cwd + timing +
    exit/signal), bounded sanitized output, network decisions/counters, resource
    use, prohibited-write audit, artifact inventory, cleanup proof, provider JSON,
    and both verdict roles. **Gate:** modifying/removing/reordering any record
    invalidates verification; redaction tests remove secret fixtures without
    destroying command meaning.
22. **Add `doctor` and rollback proof.** Doctor is local/offline by default and
    verifies controller, sandbox host, pinned image, broker, firewall ownership,
    policy schema, neutral environment, installation hashes, and stale resources;
    `--live` is explicit and separately authorized. Rollback disables only the
    integration command, drains exact owned work, revokes broker policy, removes
    installed integration files, and confirms approval review still operates.
    **Gate:** rollback rehearsal restores the pre-integration installed inventory
    and approval doctor/smoke without deleting evidence or unrelated resources.

### Phase 6 — safe live qualification

23. **Seal the candidate exact head before live work.** Run all offline suites,
    create a fresh packet, get an independent exact-head plan/diff/security review,
    and record owner-approved public canary hosts. **Gate:** no live canary starts
    unless source/policy/image digests match the reviewed candidate and protected
    Windows CI is idle per current repository rules.
24. **Run positive canaries in a disposable public fixture repository/service.**
    Execute a deterministic build/test, dependency metadata or pinned package
    fetch through a dedicated fixture registry, cited documentation search, and
    GET/HEAD to an owner-approved non-production endpoint returning a nonce.
    **Gate:** evidence ties every success to exact digests, destination, bytes,
    command, exit, citation, and cleanup; no production credential/data exists.
25. **Run negative canaries using controlled local lab targets, never real
    production/private services.** Attempt write to source input; read host secret
    marker; read inherited env/auth/SSH/browser/MCP; Git remote/push; DNS exfil
    label; direct HTTP/HTTPS; redirect allowed->denied; proxy override/tunnel;
    localhost/host gateway/RFC1918/link-local/metadata/IP literal/IPv6; package
    install script callback; test-runner callback/background child; output/disk/
    process/time flood. **Gate:** every attempt is denied at the expected enforcing
    layer, recorded without leaking marker contents, and the environment is gone.
26. **Qualify Windows dispatch.** From Windows, confirm the wrapper sends only
    digest-bound public source/policy material to the Linux controller, never
    mounts Windows drives or forwards user environment/agents/profiles, and
    receives verified evidence. **Gate:** Windows host markers and mounts are
    absent; cancellation/connection loss yields retained uncertainty, not success.

### Phase 7 — land without weakening either tier

27. **Run complete verification.** Execute new focused tests, all Grok tests,
    sandbox/packet/supervisor/installer tests, `tests/test-all.sh`, Windows
    PowerShell tests, and repository verification exactly as current docs require.
    Save case-level output under `tests/verification/grok-integration-review/`.
    **Gate:** zero failures/skips in required environments; artifact identifies
    exact head and commands.
28. **Obtain exact-head independent approval.** A reviewer other than the
    implementing session must inspect the complete diff, threat model, tests,
    live canaries, rollback, and both-tier invariant. Any source/evidence change
    invalidates approval. **Gate:** terminal APPROVE explicitly covers exact SHA,
    shell/network containment, provider gap resolution, and retained approval
    reviewer behavior.
29. **Install and verify both platforms.** Follow `docs/deployment.md`; back up
    existing configuration; install only reviewed files; verify source/installed
    hashes, local doctor, Linux qualification, Windows dispatch, and approval
    reviewer smoke. Never live-edit a server. **Gate:** installation evidence
    names exact artifact hashes and both commands remain operational.
30. **Commit, reconcile, push, and close.** Verify Git identity, stage only owned
    files, safely reconcile current `main`, rerun affected gates after movement,
    push without force, confirm commit on `origin/main`, require green CI, update
    issue #249 with evidence, update plan STATUS, and retire this handoff only
    when every definition-of-done item is proven. **Gate:** remote commit/CI/install
    evidence is reproducible and neither tier has an open regression.

## 10. Tests required

### Policy/parser tests

- Accept a minimal offline policy and the committed example.
- Reject unknown fields, missing version/source/image digest, duplicate/ambiguous
  hosts, wildcards, IP literals, userinfo, unsafe schemes/ports/methods, Unicode/
  IDNA ambiguity, private/reserved names, unbounded quotas, and command strings
  where argv arrays are required.
- Canonicalize policy and prove its digest is stable.

### Source/filesystem tests

- Live checkout never mounted or addressable; source input mount is read-only.
- Work copy initially matches source digest and HEAD; remote/helper/alternates/
  submodule escape are absent or rejected.
- Writes are limited to unique work/cache/temp/output volumes.
- Symlink, hardlink, junction, traversal, mount, `/proc`, device, socket, and
  sibling-run escape attempts fail.
- Original/source digest is unchanged; prohibited-write audit distinguishes
  expected work-copy output from forbidden input/host mutations.

### Credential/configuration tests

- Empty environment except explicit safe keys; secret-pattern and non-pattern
  fixture values are absent.
- No host home, auth store, Grok auth, Git credentials/helpers, SSH agent/files,
  browser/keychain, cloud credentials, package-manager auth, npmrc/pypirc/netrc,
  MCP, Claude/Cursor/Codex/Grok user settings, shell rc, or proxy credential.
- Provider/controller credential is unreachable from workload env, mounts,
  process list, `/proc`, error output, artifacts, and network logs.
- Every bridge-initiated execution starts from the explicit empty/safe
  environment; no earlier command can persist an environment secret into it.
- Workload trust contains ordinary public roots only; no broker/interception CA
  key or client credential exists because the broker is the endpoint TLS client.

### Network/egress tests

- Default workload namespace has no external route; the broker is unreachable
  from workload processes and callable only through structured controller tools.
- Allow exact declared dependency coordinate/digest or endpoint ID and its
  domain/port/method/path; deny undeclared subdomains and destinations.
- Deny localhost, host gateway, RFC1918, CGNAT, link-local, multicast, reserved,
  metadata, internal DNS suffixes, IP literals, IPv4-mapped IPv6, and alternate
  numeric encodings.
- Deny DNS-label exfiltration, arbitrary resolvers, DoH/DoT, raw sockets, direct
  connections, proxy override, CONNECT/WebSocket/tunnels, and request uploads.
- Re-resolve and deny CNAME/rebinding, NAT64/DNS64 synthesis including
  `64:ff9b::/96`, and allowed-to-denied redirects at every hop.
- Bound request/response bytes, decompression, redirects, retries, rate, and total
  network time; sanitize headers and never log bodies by default.

### Toolchain abuse tests

- npm/pnpm/yarn lifecycle scripts, pip build hooks, Cargo build scripts, Make,
  Gradle/Maven plugins, test framework setup/teardown, Git hooks/aliases/helpers,
  linters, language servers, and spawned shells cannot escape or contact denied
  destinations.
- Background/orphan processes, fork bombs, output floods, disk/inode fills,
  memory/CPU pressure, and signal races stay bounded and are destroyed.
- Package managers work only when their complete reviewed destination set and
  byte/time limits are declared; a new CDN/redirect fails closed with actionable
  evidence rather than auto-expanding policy.

### Grok/lifecycle/evidence tests

- Approval wrapper argv, permissions, model, exact-head, packet, locks, result,
  and verdict tests remain green unchanged.
- Integration state/session names cannot collide with approval state.
- Exact retry is idempotently refused; unrelated integration reviews follow the
  current concurrency contract; changed head/policy/image invalidates evidence.
- Invalid model/JSON/stop reason/verdict, provider loss, bridge loss, controller
  restart, cancellation, timeout, and cleanup uncertainty never return approval.
- Commands/results/citations/network decisions/resource counters/digests/write
  audits/cleanup are complete, sanitized, bounded, and tamper-evident.
- Cited search is available separately; general web fetch, MCP discovery,
  subagents, memory, and controller-local shell are absent unless explicitly
  declared and structurally constrained.

### Safe live qualification canaries

- Positive: deterministic fixture build/test; pinned fixture dependency fetch;
  cited official-doc search; GET/HEAD nonce from owner-approved public non-prod
  endpoint.
- Negative: controlled lab-only attempts covering source write, host secret read,
  inherited credential/config discovery, Git remote/push, DNS/HTTP exfil,
  redirect/proxy/private/metadata access, malicious package/test scripts, resource
  exhaustion, cancellation, and cleanup interruption.
- Never aim a negative canary at a real production/private endpoint; prove denial
  with controlled addresses and packet evidence.

## 11. Constraints, standing rules, and gotchas in force

- Planning and implementation are separate. This document authorizes no code,
  configuration, installation, provider call, network canary, or infrastructure
  mutation.
- Work directly on `main` for this repository, but preserve concurrent work and
  stage only owned files. Re-resolve live truth before the first edit/commit/push.
- Before committing, `git var GIT_COMMITTER_IDENT` must be exactly
  `Albert Hazan <u2giants@users.noreply.github.com>`.
- Reviewer safety-path changes require a read-only exact-head final review.
- Protected Windows CI/runner work is a hard stop for local reviewer suites; read
  `plan_protected-windows-run-dispatch.md` STATUS and current issue state first.
- Back up configuration before changing it; installation changes require
  `docs/deployment.md`; do not commit real `.env` or machine-local secrets.
- This public repository cannot contain raw provider transcripts, credentials,
  internal hostnames, private endpoints, or licensed/private source.
- No production/shared-cloud mutation without Albert naming the exact resource
  and action in the implementing chat. This plan contains none.
- `ai-review-sandbox` is not a security sandbox merely because of its name.
- Container root and a mounted container socket are not safe defaults. Rootless
  is necessary but not sufficient; prove the kernel boundary.
- Network allowlists drift when registries/CDNs change. Drift causes a clear
  denial and policy review, never automatic broadening.
- TLS destination validation, DNS/address validation, and routing enforcement are
  all required; any one alone is incomplete.
- Do not record secrets in command lines, process listings, logs, evidence, issue
  comments, or test output. Use synthetic markers and report only whether found.
- A successful HTTP response proves only that a declared canary responded. It
  does not prove business-flow acceptance.
- A paid provider completion without terminal verified result/evidence is
  unavailable, not approval.
- Re-read official Grok docs/source after every CLI version change; capabilities
  and failure semantics are version-bound.

## 12. Access and environment

### Planning baseline

- Repository: `C:\repos\ai-devops`, branch `main`, baseline SHA
  `bffec57fb81ae02362b54bc48831044c5abec37a`.
- Current remote: `https://github.com/popcre/ai-devops.git`.
- Machine: EDGE-DEV, Windows; Bash scripts run through Git Bash.
- Installed Grok: `1.0.5 (5115b46bc9) [stable]`.
- GitHub CLI is authenticated for issue/source-of-truth work. Grok credentials
  exist in the normal private provider home but must never be read or printed.
- No application deployment or database exists for this repository.

### Implementation environment required

- A clean isolated current-main worktree for controller/source edits.
- A dedicated non-production Linux execution host or hosted sandbox with verified
  kernel/runtime/cgroup/network primitives and no route/credentials to production
  or private networks.
- A pinned rootless OCI image or microVM image built from source-controlled,
  reviewable definitions; no `latest` tags.
- A structured fetch/endpoint broker using maintained DNS/HTTP/TLS libraries plus
  a repository-owned strict policy adapter; no transparent proxy/CONNECT path.
- Synthetic fixture repositories, registries, DNS/proxy servers, and endpoints.
- Grok authentication remains in the trusted controller/credential broker;
  reference its normal private location only. Never copy it into workload.
- Any hosted sandbox/proxy credential must live in 1Password vault
  `vibe_coding`, item name chosen and documented before use; never put its value
  in this repository or evidence.

### Platform-specific enforcement

**Linux:** use kernel-enforced read-only mounts/user namespaces/seccomp/cgroups/
network namespaces, drop capabilities, no-new-privileges, read-only root, and a
custom fail-closed Grok sandbox as defense in depth. Refuse launch if any required
primitive or deny binding is absent. Do not accept the built-in warn-and-continue
fallback.

**Windows:** do not run the capability-rich workload directly and do not claim
Grok `--sandbox` protects it. The Windows wrapper is a controller client that
packages only digest-bound source/policy and dispatches to the qualified Linux
boundary. No Windows drive, named pipe, agent, profile, credential store, or host
network is mounted/forwarded. Connection loss produces uncertainty and blocks
reuse until reconciled.

## 13. Definition of done + risks and open questions

### Definition of done

- [ ] All locked requirements in §8 map to an external enforcement mechanism,
      named test, and retained evidence field.
- [ ] `ai-grok-review` remains behaviorally unchanged and its complete existing
      suite passes on the exact landed head.
- [ ] `ai-grok-integration-review` is separately named, documented, installed,
      state-isolated, and never selected implicitly.
- [ ] Source input is exact-head/digest verified, read-only, remote-less, and
      unchanged; writable copy/cache/temp/output is disposable and bounded.
- [ ] No ambient credential/config/agent/profile/MCP/host authority reaches the
      workload; provider authentication separation is positively proven.
- [ ] Default egress is none; declared egress survives every DNS/HTTP/redirect/
      proxy/private/metadata bypass test with limits and sanitized evidence.
- [ ] Cited web research is separate from shell networking and citations are
      retained.
- [ ] Commands, outputs, network decisions, resources, digests, writes, artifacts,
      provider result, verdict, and teardown are complete and tamper-evident.
- [ ] Failure, cancellation, crash, host loss, or uncertainty fails closed and
      cannot silently leave a runnable or networked environment.
- [ ] Offline focused and hostile tests pass, then complete Bash/PowerShell/
      repository tests pass with exact-head artifacts.
- [ ] Owner-approved safe live positive and negative canaries pass on Linux and
      Windows dispatch without contacting production/internal systems.
- [ ] Independent read-only exact-head review returns terminal APPROVE after all
      source/evidence changes; exact-head approval reviewer separately remains
      operational.
- [ ] GitHub CI is green for the landed SHA.
- [ ] Installation verification proves source/installed hashes and retained
      operation of both reviewer tiers on required platforms.
- [ ] Rollback rehearsal removes only integration components and leaves approval
      review/evidence intact.
- [ ] Git identity verified; only owned files committed; current `main` safely
      reconciled; commit pushed and confirmed on `origin/main`; issue #249 updated
      with evidence; plan STATUS current; handoff retired only when truly done.

### Principal risks and mitigations

- **Credential needed by Grok:** keep provider auth in trusted controller; if the
  CLI cannot separate it from shell-visible execution, use a trusted remote tool
  bridge or stop. Never mount the token.
- **Container escape/kernel defect:** dedicated non-production runner, rootless
  runtime, microVM escalation, patched pinned host, minimal mounts/capabilities,
  and no private/production route reduce blast radius.
- **Dependency supply-chain behavior:** lockfiles, declared registries, immutable
  image/toolchain, disposable caches, egress limits, and package-script canaries.
- **Network policy parser/broker defect:** use maintained DNS/HTTP/TLS libraries,
  a small structured adapter, property/hostile tests, packet evidence, and
  fail-closed routing.
- **Evidence leaks:** synthetic secrets, structured redaction, bounded output,
  payload omission, adversarial sanitizer tests, and public-repo review.
- **Cleanup uncertainty:** revoke egress first, exact resource ledger, retained
  runner block, operator reconciliation; never broad-delete.
- **Provider upgrade drift:** version-pin qualification and refuse unknown
  inspect/tool/sandbox schemas until reviewed.
- **False confidence from successful tests:** independent exact-head approval,
  complete suites, negative canaries, install hashes, and both-tier smoke.

### Genuinely unresolved provider/platform limitation

Grok 1.0.5 supplies shell and cited web tools, but it does not supply a complete
cross-platform containment and domain-egress architecture. In particular, its OS
sandbox does not enforce on Windows, Linux child-network restriction is not a
domain allowlist, in-process web/LLM networking remains outside that restriction,
and the ordinary CLI authentication file cannot be placed where a shell can read
it. Phase 0/4 must prove a controller-to-sandbox tool bridge that keeps reusable
provider credentials outside the workload. Failure to prove that requires an
external trusted controller plus container/microVM/structured egress broker or
hosted sandbox;
it does not justify widening the approval reviewer.

### Rollback and retained evidence

Rollback is a reviewed, exact-target uninstall/disable of the new integration
command, policy, broker registration, and owned disposable resources. It does not
change or delete `ai-grok-review`, other reviewer state, raw source, or retained
sanitized evidence. Before rollback, revoke integration egress and stop exact
owned workloads; after rollback, verify no process/network/resource remains,
source/installed inventories match the recorded pre-change baseline, approval
review doctor/smoke still passes, and issue evidence explains why rollback was
needed. Ambiguous cleanup blocks the runner rather than guessing.

---

## Mandatory plan self-audit — final pass

### Objective checklist

- [x] All 13 required sections are present.
- [x] The plain-English ultimate goal is first and says the goal wins on conflict.
- [x] A fresh session has repository/provider/platform baseline, exact paths and
      current line references, ordered phases, dependencies, and gates.
- [x] Rejected approaches and why they fail are explicit in §7.
- [x] Every implementation step names concrete proposed/existing files, functions,
      behavior, dependencies, and a verification gate in §9.
- [x] Locked versus open decisions are labeled in §8.
- [x] Out-of-scope work is explicit in §4.
- [x] Tests are named by behavior in §10, including offline and live canaries.
- [x] Newcomer terms, paths, issue numbers, platform roles, URLs, and baseline SHA
      are defined or linked.
- [x] Secrets are referenced by location/class only, never by value.
- [x] Definition of done includes exact-head independent review, complete tests,
      CI, installation/source hashes, commit/push verification, rollback, and both
      reviewer tiers remaining operational.
- [x] Plan and unique HANDOFF.d file link to each other; root `HANDOFF.md` is
      untouched.

### Required questions

1. **Could a brand-new AI session execute this perfectly without asking for
   missing project context? Yes.** §§2, 3, and 5 establish the exact current
   baseline; §§8 and 9 define the architecture, decision gates, files/functions,
   sequence, dependencies, and proof; §§10-13 define qualification and landing.
2. **Does the plan carry the background, nuance, and rejected reasoning? Yes.**
   §§3, 6, and 7 preserve the provider facts, trust-boundary root cause, abuse
   paths, and every unsafe shortcut; §11 preserves repository/concurrency rules.
3. **Is the ultimate goal clear enough to steer a correct judgment when a step
   is wrong? Yes.** §1 defines the business outcome and goal-wins rule; §8 labels
   every locked invariant and gives evidence-based criteria for open choices;
   §13 requires stopping rather than weakening containment.

No checklist gap remained after the final pass.

### GLM 5.3 debate record (2026-09-03)

The persistent read-only session `grok-integration-review-plan` completed one
initial review and two rebuttals. Round 1 rejected four gaps: the deterministic-
harness alternative was unaddressed; Windows-to-Linux transport/auth was vague;
controller web-fetch egress contradicted the containment doctrine; and transparent
TLS enforcement was ambiguous. Round 2 confirmed those corrections and found two
stale phrases. After both were aligned, round 3 returned **APPROVE** and
`CONSENSUS: plan is the best safe plan as written`.

The consensus specifically confirms the separate approval-tier invariant, fully
offline workload, structured dependency/endpoint broker, controller-only
credentials, mutually authenticated Windows dispatch, DNS/HTTP/package/test/Git
abuse coverage, platform split, executable gates, and consolidated owner choices.
It authorizes no implementation or live canary; Phase 0 must re-pin provider facts.
