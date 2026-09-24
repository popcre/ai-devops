# DeepSeek V4.1 Flash re-entry evidence (2026-09-23)

Owner instruction (Albert, chat): "put DeepSeek back on the reviewer list".
Model pin: `deepseek-flash` (DeepSeek V4.1 Flash). Precedent: Gemini re-entry, 2026-09-06.

## Live qualification

`ai-review-preflight check deepseek <repo> --live`, run on the final wrapper of this branch
(after the `DEEPSEEK_TOOLS_*` budget fix, commit dd46fa4, and the DSML recovery fix):

    PASS provider=deepseek repository=C:/repos/ai-devops/.claude/worktrees/deepseek-pool-4149613 packet=verified health=ok allowance=live-verified

## Live governed review of a real merged commit

Target: merged commit `e2e41104735a0c3e1981dabccbdc9089f109d970` (PR #740), reviewed from a
detached checkout of that commit with
`ai-deepseek-agent send --review --governed-verdict <sha> --model deepseek-flash`.
Session `20260923-232833-112369`, exit 0, 9,196-character report that cites
`.github/workflows/verify.yml` and `tools/ci/runner-router.cjs` line numbers obtained through
the read-only repository tools. Terminal line:

    VERDICT: REVISE e2e41104735a0c3e1981dabccbdc9089f109d970

## Failure found and fixed on the way

An earlier run ended `invalid-terminal-verdict` because in round 15 the model returned its
tool call as DSML markup in plain message text. `tools/deepseek_repo_tools.py` now recovers
and runs such calls and refuses unparseable markup as a final answer (tests in
`tests/test_deepseek_repo_tools.py`).

The review's substantive finding about PR #740 routing is owned by the coordinator's #740
security follow-up, not by this change.
