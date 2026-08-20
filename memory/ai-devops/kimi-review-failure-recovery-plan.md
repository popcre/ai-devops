# Kimi review failure recovery plan

Issue `u2giants/ai-devops#46` governs the active Kimi review quarantine and
repair. Read `plan_kimi-review-failure-recovery.md` and its STATUS table first;
do not re-derive the 2026-08-19 incident from chat or restore Kimi to rotation
before merged installed live qualification passes.

Key correction: the named ten-job set contained nine explicit usage-limit exits
and one unexplained exit 127, not nine exit-127 deaths. Historical findings-tail
truncation was already fixed by commit `f65cc77`. Active work concerns durable
worker-owned reports, correct ignored-folder probing, incomplete-output recovery,
typed diagnostics, and survival after caller-created temporary copies disappear.
