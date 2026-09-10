# Issue #373 Blacksmith ACL repair evidence

## Scope

The `ai-gemini` Windows failure-evidence ACL check now compares security
identifiers rather than an evaluated account display name. It requires disabled
inheritance, Full Control for the current SID, and rejects every Allow ACE other
than the current SID, Local System (`S-1-5-18`), or built-in Administrators
(`S-1-5-32-544`). The wrapper version is `0.2.3`.

## Diagnostic evidence

Throwaway Blacksmith run
[34525600699](https://github.com/popcre/ai-devops/actions/runs/34525600699),
commit `5f9dbe1d`, printed ACL metadata only. Section 3 showed:

- current account `WIN-FE737MTRSOT\runneradmin`;
- current SID `S-1-5-21-2104560516-1673140205-1413357928-1003`;
- `icacls` exit 0 and an ACE for that same display name;
- the old evaluated display-name assertion still failed because its backslash
  was interpreted during evaluation.

No failure-evidence contents were printed.

## Runtime verification

- Focused Windows Git Bash run of `tests/test-ai-gemini.sh` on commit
  `5458ef5c`: **67 passed, 0 failed**. This includes disabled inheritance,
  SID-based matching, a forced `icacls` failure, and rejection of a pre-seeded
  Everyone Full Control ACE.
- Blacksmith run
  [34528195617](https://github.com/popcre/ai-devops/actions/runs/34528195617),
  commit `66e4af46`: all four sections passed, including section 3 with the ACL
  change and regressions.
- Blacksmith run
  [34530636899](https://github.com/popcre/ai-devops/actions/runs/34530636899),
  commit `5458ef5c`: ACL-owning section 3 passed. Sections 2 and 4 also passed;
  unrelated section 1 failed eight existing Kimi lifecycle/timing checks. No
  Kimi file changed.
- Pull-request verify run
  [34530641776](https://github.com/popcre/ai-devops/actions/runs/34530641776),
  commit `5458ef5c`: Linux and hosted Windows sections 2, 3, and 4 passed. At
  evidence capture time section 1 and the reviewer lane were still running.

## Final acceptance

PR #385 merged through the queue as
`1fcc63510702d393086563f3e0dfa06df3491ccc`. Post-merge Blacksmith run
[34536475882](https://github.com/popcre/ai-devops/actions/runs/34536475882)
then passed all four sections and the aggregate job against `main`. Issue #373
closed on 2026-09-10.
