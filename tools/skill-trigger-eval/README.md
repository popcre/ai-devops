# skill-trigger-eval

Measures whether a Claude Code skill actually fires on realistic prompts.

```bash
python tools/skill-trigger-eval/skill-trigger-eval.py \
  --skill secrets-to-1password \
  --eval-set tools/skill-trigger-eval/secrets-to-1password.eval.json
```

Needs the `claude` CLI logged in (`claude auth status`) and the skill installed
(`bin/ai-install-skills`) — it tests the real skill in `~/.claude/skills`, via
the real `Skill`-tool mechanism.

Full context, the two traps in the bundled skill-creator harness, and how to read
a "miss" honestly: **`docs/skill-trigger-eval.md`**. Read it before acting on a
low score — the first 1Password run scored 2/10 because the *eval set* was wrong,
not the skill.

Eval sets live here as `<skill-name>.eval.json`. Note `.gitignore` has a narrow
negation for `*secret*.eval.json` in this directory; a set whose filename
contains "secret"/"token"/"private" is otherwise silently refused by `git add`.
Prompt sets must never contain real credential values — a prompt only needs to
mention a credential to test triggering.
