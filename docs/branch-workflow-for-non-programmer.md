# Branch Workflow (for a non-programmer)

A plain-English guide for Albert. You don't need to know how code works to keep
the AI workflow safe — just follow these habits and watch for the warnings.

## The big idea

Think of the code like a shared document.

- **`main` is the "official" version.** Never let changes happen directly on it.
- **A "branch" is a safe scratch copy.** The AI does its work there. If it goes
  wrong, you throw the scratch copy away and `main` is untouched.
- **A "PR" (pull request) is the review step** where a change on a branch is
  proposed to become official.

## Your safety command

Before and after any task, run:

```bash
ai-workspace-status
```

It tells you, in plain terms:

- which copy (branch) you're on,
- whether there are unsaved changes,
- whether you're accidentally on the official `main` copy,
- whether a PR is already open.

## The two warnings to never ignore

1. **"You are on main/master"** — Stop. The AI should make a branch first.
   Nothing risky should happen while you're on the official copy.
2. **"Working tree is DIRTY"** — There are changes that haven't been saved
   (committed) yet. Don't switch tasks or start something new until these are
   handled, or you can lose work.

## A normal task, start to finish

1. Ask for the task. Codex/GPT-5.6 plans it and Claude Opus 5 checks the plan.
2. The AI makes a branch and writes the code (GPT-5.6 / Codex, medium reasoning).
3. Claude Opus 5 checks the code, then the security, then the final result.
4. You get a **plain-English summary** of what changed and whether it's ready.
5. If it's ready, it becomes a PR and then gets merged into `main`.

## What the AI will never do without asking you

- Merge into the official `main` copy.
- Delete branches.
- Force-overwrite history.

If anything ever asks you to approve one of those, and you're not sure — pause
and ask.
