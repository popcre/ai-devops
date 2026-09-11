# #394 Grok and Muse terminal reasons

Grok's failed finish returned under shell errexit before either dispatch wrote
its terminal diagnostic. The session knew the provider stop token, but the
diagnostic remained at launch. Capturing the status now reaches the diagnostic
write; explicit output checks preserve failure behavior under that capture.

Cancellation is `provider_cancelled`. Only explicit provider turn-limit tokens
become `turn_limit_cancelled`; reaching a numeric ceiling does not prove why a
provider cancelled. Unknown tokens produce `unknown_terminal_reason`, with the
original value retained privately. Session metadata and lifecycle diagnostics
carry the same mapped reason exposed to the governed consumer.

An unsuccessful turn prepares an explicitly incomplete private report containing
the paid result and stderr, then uses the existing evidence publisher before
cleanup. Publication failure retains every source file. No provider body is
printed as an accepted review, and output failure cannot become success.

Muse now marks refusals before session creation as `start_failed`, with exact
missing/invalid caller subreasons. Errors belonging to an existing session keep
their original classification. Ordinary help, debate and required-verdict
behavior remain unchanged. The historical transient start failure's underlying
cause is still unknown; these changes provide a recognizable diagnostic.

Validation: Grok reason/fault checks 13 passed, zero failed; provider-shaped
new/continuation checks 25 passed, zero failed or skipped. Muse startup checks
failed three cases before repair and now pass all five. Governed-consumer
mapping passes 59 checks, zero failed or skipped, including refusal of a fake
approval attached to every typed error and privacy of raw diagnostic bodies.
Combined accounting compatibility also passes all 14 checks. Independent review
approved the implementation and identified two small diagnostic improvements:
incomplete staging reports now use private temporary-file creation, and unknown
terminal guidance names durable invocation evidence rather than a cleaned-up
staging path. The 13 reason/fault checks pass after those improvements.

Independent exact-head review, required CI, installation and affected private
incident reconciliation remain pending. No turn ceiling, permission, accounting
rule, provider selection or database structure changed.
