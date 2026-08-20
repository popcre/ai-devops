# The false `.ai/reviews is not git-ignored` warning — four wrappers, one bug

**Status:** open, unfixed as of 2026-08-20.
**Affects:** `ai-kimi`, `ai-grok-review`, `ai-gemini`, and the save path around `ai-muse`.
**Severity:** higher than it looks. It silently suppresses the artifact that makes a
lost review recoverable.

## The symptom

On essentially every run, the wrapper prints:

```
warning: not writing a review file: '.ai/reviews' is not git-ignored in <path>
(it would be committable). Add '.ai/reviews/' to .gitignore.
```

…and then does not write the review file.

## The warning is false

In `u2giants/shared-db`, **line 36 of `.gitignore` is literally `.ai/reviews/`**. Lines
36-38 are:

```
.ai/reviews/
.ai/runs/
.ai/tmp/
```

And `git status --porcelain` immediately after a review run is **empty** — nothing
untracked, nothing modified. Git is ignoring the directory exactly as intended.

So the repository is configured correctly and the wrapper's check disagrees with Git
itself.

## Why it matters much more than a spurious warning

The suppressed file is not a convenience. **It is the recovery path when a wrapper
mishandles its own output**, and both known cases of that happened on 2026-08-19.

**`ai-kimi` — the review was destroyed.** On rotation sequence 202 (shared-db PR
#1233), Kimi returned a correct `VERDICT: REVISE` naming one blocking finding, and the
finding itself never reached the caller. The extractor keeps everything from the LAST
heading onward and discards the rest. Nothing else persisted it:

- `ai-kimi show` and `ai-kimi transcript` both failed from the review sandbox
- the session JSON at
  `~/.local/state/ai-devops/kimi/sessions/4c4d070b02d7/claude--seq202-…json` holds
  **metadata only** — twelve keys, no message content
- and the review file that would have been the last surviving copy **was not written,
  because of this warning**

A full review cycle was spent burning the reviewer and rotating to a replacement.

**`ai-muse` — the review survived, because it saved the file anyway.** On the
2026-08-19 reviewer trial, Muse produced a complete seven-point review ending in
`VERDICT: APPROVE`; the wrapper failed to detect that verdict and wrote *"Muse did not
produce the required final verdict. This is not a review result."* over correct work.
**The review was fully recoverable from
`.ai/reviews/muse-incomplete-20260820T012150Z.md`.**

That contrast is the whole argument for fixing this. Same class of extraction bug in
two wrappers; the one that wrote its artifact lost nothing, the one that skipped it
lost everything.

## Likely cause and the fix

The check appears to be a string comparison over `.gitignore` contents rather than a
question put to Git. A pattern written as `.ai/reviews/` (with the trailing slash), or
inherited from a parent `.gitignore`, or matched by a broader rule, will not be found
by a naive substring search for the exact path being tested.

**Use `git check-ignore` instead.** It is the authoritative answer and handles
trailing slashes, negations, parent-directory rules and the global ignore file:

```sh
if git -C "$repo" check-ignore -q "$repo/.ai/reviews/probe.md"; then
  # ignored — safe to write
fi
```

Note `check-ignore` tests a *path*, so probe a file inside the directory rather than
the directory itself.

**Fail loudly, not silently.** If the check genuinely says the directory is not
ignored, the wrapper should still say plainly that it is discarding the review, and
ideally write to a location outside the repository rather than dropping the content.
Losing a review because a repository is misconfigured is the wrong trade — the review
is the expensive artifact, the warning is cheap.

## How to verify a fix

In a checkout of `u2giants/shared-db`, run any wrapper review and confirm:

1. no `.ai/reviews is not git-ignored` warning is printed;
2. a review file appears under `.ai/reviews/`;
3. `git status --porcelain` is still empty afterwards (the file is ignored, so it must
   not show up as untracked).

All three must hold. Point 3 is what the warning was trying to protect and is worth
keeping.

## Related records

- Reviewer issue `20260820T004602Z-edge-dev-kimi-k3-385556` — the Kimi failures,
  including the destroyed review this warning made unrecoverable.
- Reviewer issue `20260820T013646Z-edge-dev-muse-spark-1.2-contributor-394599` — the
  Muse verdict-detection defect, recoverable *because* its output was saved.
- `docs/reviewer-trial-2026-08-19-glm-gemini-muse.md` — the trial in which this was
  confirmed across four wrappers.
- `u2giants/shared-db#1220` — reviewer wrappers exiting 0 with no verdict.
