# Phase 2 verification — the central task-gate engine — 2026-09-08

Owner issue: [popcre/ai-devops#335](https://github.com/popcre/ai-devops/issues/335).
Plan: [`plan_cross_repo_routing_and_gate_enforcement.md`](../../../plan_cross_repo_routing_and_gate_enforcement.md).

## What was built

`bin/ai-task-gates` answers two separate questions from one contract
(`config/task-gates.json`, validated against `config/task-gates.schema.json` by
`tools/ci/validate-task-gates.py`):

1. **What changed?** Every changed path is mapped to a change class. The
   complete change set is used — committed changes against the base, staged,
   unstaged, untracked, deletions, *both* sides of a rename, and dirty
   submodules — and the strongest class across all of them wins.
2. **Which gates apply?** Each class declares the proofs it requires and the
   actions it forbids.

Strength is structural, not procedural. A repository's own
`.ai-devops/task-gates.json` is merged by taking the maximum rank per path, so a
local declaration can raise a class and can never lower one. A `protected`
class — reviewer safety, UI/live workflow, shared database, deployment,
infrastructure, production, private evidence — cannot be lifted by
`--acknowledge` or `--owner-request` at all. Anything the tool cannot classify,
including an unresolvable repository identity, refuses a protected action rather
than allowing it (exit 4).

## Where it is enforced

The gate runs at the three places where something expensive or risky actually
begins, and in every case *before* a lock, a state file, or a provider process
exists, so a refusal costs nothing:

| Entry point | Action | What a refusal prevents |
|---|---|---|
| `bin/ai-review` | `review` | The approval-gate front door never reaches a provider wrapper |
| `bin/ai-review-lifecycle begin` | `review` | No assignment lock, no lifecycle state, no preflight, no paid call |
| `bin/ai-pr-wait` | `pr-wait` | No long wait on a pull request that should merge immediately |

`ship`, `deploy`, `database`, `infrastructure`, and `production` are enforced by
the class contract itself plus an explicit `ai-task-gates check --before
<action>`; there is no single shipping binary to hook.

The legacy CI classifier contract is unchanged: `tools/ci/classify-changes.sh`
now delegates to the shared library, and the suite asserts its output is
identical to `ai-task-gates classify` for the same input.

## Evidence

Re-run:

```bash
bash tests/test-ai-task-gates.sh
bash tests/test-ai-review-lifecycle.sh
bash tests/test-ai-pr-wait.sh
python tools/ci/validate-task-gates.py config/task-gates.json
```

| Suite | Result |
|---|---|
| `tests/test-ai-task-gates.sh` | 68 passed, 0 failed |
| `tests/test-ai-review-lifecycle.sh` | 46 passed, 0 failed |
| `tests/test-ai-pr-wait.sh` | 26 passed, 0 failed |
| `tests/test-workflow-policy.sh` | all assertions pass after the declared suite count moved from 66 to 67 |
| complete offline Bash suite (`tests/test-all.sh`) | 67 suites, 1 failure, pre-existing |
| complete offline PowerShell suite (`tests/test-all.ps1`) | 18 suites, 0 failures |

The complete offline runs were done in sequence, never concurrently, because two
full suites on this host contend and produce false failures.

The single remaining Bash failure is `test-line-endings.sh`, which reports that
54 files in this checkout are CRLF in the working tree. That is the known
pre-existing state of a checkout made before `.gitattributes` landed. Every file
added by this work is LF, and no existing file was converted.

An earlier Bash run also failed two `test-ai-grok-review.sh` capacity assertions
and two named-session concurrency fixtures. Both cleared on the sequential
re-run; `bin/ai-grok-review` does not reference the task gate, so nothing in this
change set reaches it.

The new suite covers, by name: every change class; mixed change sets taking the
strongest class; an unmatched path falling back to `code` rather than to prose;
a consumer declaration that cannot downgrade a protected class but can
strengthen one; untracked, deleted and renamed files; repositories with spaces
in the path, no remote, no commits, a detached HEAD, and a clean tree; stale and
corrupt intent state; linked worktrees and two concurrent tasks; submodules;
each gate and both overrides; the undeclared-task fallback; the legacy CI
contract; and usage errors.

Injected-defect checks prove the contract is actually enforced rather than
merely described: a policy whose fallback is the weakest class, a path rule
naming an undeclared class, an unrecognised top-level key, and a consumer
declaration that is not valid JSON are each rejected.

The documentation-only refusal fixture is asserted directly in
`tests/test-ai-review-lifecycle.sh`: after a prose task is declared, `begin`
exits non-zero, the provider preflight log is empty, no lifecycle state file was
written, and no assignment lock is left behind. Adding a migration file to the
same tree escalates the class and the refusal names the file that caused it.

## Independent review

`ai-review claude final-check` rejected the first head (`4fffcb31`) on three
findings, all fixed here:

1. `bin/ai-task-gates` was committed non-executable. On Linux the shared
   preflight skips a gate it cannot execute, so all three enforcement points
   would have silently allowed everything, and an existing installer test would
   have gone red. The recorded mode is now `100755`.
2. A consumer declaration that is not valid JSON failed open: the refusal ran
   inside a command substitution, so it ended only the subshell and
   classification continued on the central rules alone. Validation moved to the
   main shell at identity resolution, with three tests covering it.
3. `AGENTS.md` overstated the protected-class guarantee. It now says plainly
   that the way past a protected class is to redeclare the task at the stronger
   class and meet what that class requires.

`ai-review codex final-check` could not run: its sandbox policy blocked every
read-only command, including the first required read.
