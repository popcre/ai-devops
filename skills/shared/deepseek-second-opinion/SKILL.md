---
name: deepseek-second-opinion
description: Debate a plan, diagnosis, design, diff, or configuration with DeepSeek through ai-deepseek-agent. Use for "ask DeepSeek", "run this by DeepSeek", "what does DeepSeek think", "debate DeepSeek", or a DeepSeek second opinion. Report its view and push back when needed.
---

# deepseek-second-opinion

A **debate**, not a delegation, and not a diff-only reviewer. DeepSeek is a
genuinely independent model family with a clean context window on every new
session, so it is a real check on Claude's or Codex's reasoning -- but only if
the calling agent commits to its own position first and then argues honestly.
This skill runs that loop for *anything*: an implementation plan, a design, a
bug diagnosis, a piece of code, a `.toml`/`.env`/config question, "why is this
server behaving this way", or a straightforward code review if that's genuinely
all that's wanted.

The failure mode this exists to prevent: the calling agent reads DeepSeek's
answer, finds it plausible, and folds. Two models agreeing because the second
one anchored on the first is worth nothing. The value is in genuine
independence, then genuine argument.

## Trigger phrases

- "run this by deepseek", "what does deepseek think", "see if deepseek agrees"
- "ask deepseek", "get deepseek's opinion", "debate this with deepseek"
- "talk to deepseek about the environment / this config / this error"

## Transport: `ai-deepseek-agent`

DeepSeek has no native CLI with session-resume the way Codex does, so this
toolkit provides its own thread-preserving wrapper around the DeepSeek API.
Every turn resends the full conversation so DeepSeek has real context, the
same effect as `codex exec resume`.

This text-and-file transport is intentional. As verified on 2026-08-10, Codex
0.145.0 custom providers accept only the Responses API wire format, while the
DeepSeek API exposes its agent tool calls through Chat Completions. Do not add a
`deepseek` Codex provider/profile unless both vendors later document one common
supported wire format and a live read/write canary re-proves structural read-only
behavior. Attach the exact files DeepSeek needs with `--file` instead.

```bash
# Turn 1 -- start the conversation, get back a SESSION_ID
ai-deepseek-agent send "<the brief -- see Step 2>" [--file path/to/diff-or-plan.md]

# Turn 2+ -- continue the SAME conversation (rebuttal, follow-up questions, ...)
ai-deepseek-agent reply <session-id> "<your rebuttal or follow-up>"

# Re-read the whole thread at any point
ai-deepseek-agent show <session-id>
```

Session IDs are deliberately restricted to letters, numbers, dots, dashes, and
underscores. The wrapper rejects hidden names, path separators, Windows device
names, linked session files, and linked session storage. Do not rename a session
file by hand to work around that protection.

Each successful turn commits the user message and DeepSeek reply together. If
the provider fails or a review has no usable verdict, the stored conversation
does not advance. Replies to one session are serialized, so never bypass the
wrapper to edit its JSON transcript. Provider calls have connection and total
time limits. On interruption, the wrapper stops and waits for its owned request
before releasing the session lock, so a second turn cannot overlap it.

For a formal review, add `--review` to `send` or `reply`. That mode requires a
literal `## Verdict` section with `APPROVE`, `REJECT`, or `BLOCKED`, and writes a
metadata sidecar bound to the session and exact Git HEAD. It refuses before
provider contact when no Git commit can be resolved. A nonzero result is
incomplete evidence, never approval. Set `AI_DEEPSEEK_CALLER` to the client
running the review (`codex` or `claude`) so later incident evidence can match the
exact caller instead of recording it as `unknown`.

`--file FILE` appends a file's contents to the message -- use it to attach a
diff, a plan document, a config file, a log excerpt, whatever DeepSeek needs
to see, instead of inlining a huge blob on the command line.

DeepSeek's API key is a managed 1Password reference (`config/mcp.env.example`);
`ai-deepseek-agent` resolves it itself, so nothing needs to be exported by
hand on any machine.

Never paste a secret value into the brief. Point DeepSeek at facts, not
credentials -- there is no sandboxing on the DeepSeek side the way `codex exec
-s read-only` provides, so the discipline has to be in what you send it.

## Step 1 -- commit to your own position FIRST

Before DeepSeek sees anything, write your own position down (in your own
scratchpad, or just hold it clearly in your own reasoning): the claim, your
reasoning, your confidence, and the specific thing that would change your
mind. This is the anchor that makes Step 3's comparison honest. Skipping it
means you can't tell agreement from anchoring afterwards.

If you genuinely have no independent read (the question is outside what you
can assess), say so plainly rather than manufacturing a position.

## Step 2 -- send the material and your position to DeepSeek

DeepSeek starts with **zero knowledge of this session**. The message is the
whole handoff -- write it like a brief to a stranger who just walked in.
Include:

- **The material** -- the plan/diagnosis/design/diff/config/log itself, in
  full (use `--file` for anything long). Exact file paths, function names,
  error text. Never "the relevant file"; name it.
- **The question** -- what you want judged or discussed, stated sharply.
- **Your position** -- include it, clearly labelled as one input to weigh, not
  the expected answer. Tell DeepSeek to reason from the material first and say
  plainly if you're wrong.
- **The required output** -- its own verdict/answer, its reasoning, its
  confidence, where it agrees and disagrees with your position and why.

## Step 3 -- report DeepSeek's answer, then your agreement

Two clearly separate things, in this order -- never blend them into one voice:

1. **What DeepSeek said.** Faithfully, including anything inconvenient for
   your position.
2. **Whether you agree**, per point, with reasoning. Partial agreement is the
   common case.

If DeepSeek changed your mind, say so and stop -- that's the point of the
exercise, not a loss.

## Step 4 -- the rebuttal round (only on real disagreement)

Only if you still disagree on something that matters. Continue the **same**
session id with `ai-deepseek-agent reply` so DeepSeek is arguing with its own
prior reasoning in context, not starting cold. Name the specific claim you
reject, give the evidence DeepSeek didn't have or didn't weigh, and ask
directly whether that changes its answer -- and to say plainly if it does not,
rather than splitting the difference to be agreeable.

**Cap it at two rounds.** Past that, models converge on politeness rather than
truth. An unresolved disagreement after two rounds is a real finding, not a
failure -- report it as one.

## Step 5 -- the verdict

Close with exactly one of these, in plain English:

- **Agreed** -- independently reached the same conclusion. (Note when DeepSeek
  merely confirmed rather than tested -- cheap agreement isn't strong
  evidence.)
- **DeepSeek conceded** -- it changed its answer after the rebuttal, and why.
- **I conceded** -- you changed yours, and what specifically moved you.
- **Still split** -- state the crux: the one factual question or judgement
  call the disagreement reduces to, and what would settle it. This is the most
  valuable outcome of all; never paper over it with a false "we broadly agree".

Then say what you recommend doing about it.

## Utility commands

- `ai-deepseek-agent list` -- see open session ids for the current repo.
- `ai-deepseek-agent show <session-id>` -- re-read a whole thread later.

## Anti-patterns

- Reading DeepSeek's answer before committing to your own position first.
- Folding because DeepSeek sounds confident, or holding your position out of
  stubbornness. Both are failures of the same thing: arguing from the
  evidence.
- Softening DeepSeek's disagreement when reporting it.
- Starting a **new** session for the rebuttal instead of `reply`-ing to the
  existing one -- that throws away the context that makes the rebuttal real.
- More than two rebuttal rounds, or reporting "we agree" when actually split.
- Pasting a connection string, token, or key into a message.
- Treating this as a diff-only reviewer -- it isn't one. Use it for plans,
  environment questions, debugging theories, anything worth a second opinion.
