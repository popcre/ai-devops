# StepFun OpenCode profile

The explicit `compaction` block was restored from the qualified profile. Its
effect on pinned OpenCode 1.18.12 has not been measured against the defaults.
Do not remove or tune it as a token optimization until paired measurements and
retained-fact checks show that review correctness and isolation still hold.

## Verdict-stop plugin

`plugin/stepfun-verdict-stop.js` is copied into every StepFun OpenCode turn
(review door and `bin/ai-stepfun`, Windows and Linux). After OpenCode 1.18.12
auto-compacts a session it injects a synthetic "Continue if you have next
steps" message; once the model has written its final `## Verdict` block the
plugin declines that continue, so a finished review ends instead of running
on. Compaction before the verdict still continues as before.
