# Handoff: edge-dev3 heartbeat rebuild as one shared note (open, not started)

Unfinished work: [plan_heartbeat-shared-note.md](../plan_heartbeat-shared-note.md)
— read its STATUS table first. Nothing is built yet. Issue: popcre/ai-devops#2346.

State that matters right now:

- The heartbeat timer on edge-dev3 was switched off on purpose on
  2026-11-18 2:42 PM EST (owner instruction) because it was a main cause of the
  GitHub allowance running out. Until the plan's step 5, every routed job in
  the 28 listed repositories runs on GitHub's machines (paid minutes for the
  private DesignFlow repositories).
- Do not simply switch the old timer back on; that restores the problem.
- The plan supersedes [plan_issue-2346.md](../plan_issue-2346.md).

Not covered by the plan, found the same day and still open: AI sessions on the
server hetz and one CI review job also use the personal GitHub login heavily;
the separate shared-db runner heartbeat on edge-dev3 is still running.
