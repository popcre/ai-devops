# Reviewed HTS sandbox application workflow

Owner: Codex; application outcome: DesignFlow backend issue #94. Central safety
delivery belongs to ai-devops #335. PR171 integration remains Uma's responsibility.

The database gate correctly refuses SQL and shared structural work from a source
safety task. Ordinary authenticated application learning needs its own route.
Do not remove any existing forbidden action or relabel the task to evade it.

Implement one `application-workflow` action with a mandatory committed
`.ai-devops/application-workflow-target.json`, canonical backend origin, effective
reviewer-safety or ui-live-workflow class, and an independent exact-head final-check
or security-review APPROVE. The central target fixes the Alsand sandbox service,
API origin, issue94 and the ordinary CROSS evidence, precheck, shadow classification,
inquiry-history and inquiry-answer routes. The committed declaration permits only
non-operative learning and replay/retrieval/visual acceptance. No SQL, schema,
cloud mutation, worker flag change, manual promotion, RFQ Apply/Save, production
cutover or DesignFlow merge is admitted. Read-only target identity proof is still
required immediately before execution; the gate is an admission receipt, not an
HTTP proxy or an execution sandbox.

Verification: preserve all existing task-gate tests; add adversarial cases for
wrong origin/target/class, missing or dirty/symlinked/duplicate manifest, stale or
non-independent review, missing declaration, and failed receipt persistence.
Run schema validation and Bash syntax checks. Obtain independent exact-head review,
merge through normal queue, install through the existing reviewed Linux route and
prove the installed command accepts only the declared sandbox workflow. Then refresh
the live backend source, review its exact workflow declaration and execute the
genuine HTS case. Preserve every previous proof and refusal.

Verification checkpoint, October11, 8:58 AM EDT: behavioral source
`911a1ce6` was archived from Git and tested on the isolated vps2-direct host after
its collision check passed. The complete task-gate suite passed358/0, including
failure to persist the workflow receipt. The CI-reported missing reviewer-path
registration is corrected; the focused guard covers75 dependencies and passes.
Bash syntax, policy schema and whitespace checks pass. Actual history-detail and
admin-detail route patterns are now explicit. These are source/test results;
merge, protected installation and DesignFlow #94 live acceptance remain open.
