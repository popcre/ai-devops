# Codex Windows containment qualification — September 11, 2026

Issue #271 remains **open** under #337. Repository reads now work, but the
required approved-snapshot-only boundary is not enforced by the tested native
Windows runtime. Refusing unsafe work is not delivery of the reviewer capability.

## Measured result

The isolated official Codex CLI 0.154.0 runtime was exercised without a model
request, through its app-server `command/exec` method. This method runs a command
without creating a thread or turn. A fresh synthetic fixture contained an
approved marker and a sibling outside sentinel. The selected named permissions
profile used the elevated Windows backend and disabled network access.

- With `:root = "deny"`, `:minimal = "read"`, and the approved directory reopened
  for reading: the marker read succeeded, a source write failed, **the outside
  sentinel read succeeded**.
- With `:root = "read"` and the outside directory explicitly denied: the marker
  read succeeded, the write failed, and the outside sentinel read failed. This
  confirms that explicit deny propagation works through this execution route;
  it does not establish an allowlist boundary against every other path.
- A local HTTP canary returned its synthetic response through `curl.exe` in both
  profiles despite `network.enabled=false`. This proves loopback access remained
  possible. External network egress was not tested and is not inferred.
- Both completed command responses returned exit code 0. The test inspected each
  operation result; process success alone would have falsely passed containment.

An initial network test used a PowerShell type prohibited by constrained language
mode. That result was inconclusive and was replaced by the actual HTTP canary.
No private file was read, no provider request was made, no global runtime or
configuration was replaced, and no production resource was changed.

## Root cause and upstream disposition

The documented root-deny profile is unsupported by the elevated native Windows
implementation. Upstream commit
[`f11d0dd`](https://github.com/openai/codex/commit/f11d0dd0120ed936629acb57385090e5317e3903),
merged September 9 at 22:50 UTC, explicitly validates effective root read access
and rejects root-denying policies. Its explanation states that the elevated
Windows sandbox cannot safely enforce filesystem-root read denial. The official
0.154.0 release was published at 22:35 UTC, before that change.

Upstream [#42184](https://github.com/openai/codex/issues/42184) records the same
root-deny failure and is closed. Its closure must not be interpreted as an
implemented snapshot-only read boundary: the corrective change rejects the
unsupported policy. The wrapper cannot repair this by changing the selected
profile name or merely updating to that refusal behavior.

The standalone `codex sandbox` diagnostic route has a separate reported
[deny-override propagation problem](https://github.com/openai/codex/issues/43362).
The app-server measurement above avoids relying solely on that diagnostic path.

## Remaining acceptance

Preserve #271's allowed marker/diff read, denied source write, denied network,
denied outside read, and substantive exact-head review requirements. Do not
substitute broad root reads, enumerated sensitive-folder denials, an unrestricted
helper, or a successful `BLOCKED` verdict for those requirements. Qualify an
actually supported containment implementation before spending on a live review.

Doctor/preflight should eventually distinguish infrastructure failure from a
review decision and exercise real canaries through the same policy/dispatch path
as the reviewer. A command-presence or version check is insufficient. No reviewer
capability was removed as part of this diagnosis; implementation and installed
acceptance remain pending.
