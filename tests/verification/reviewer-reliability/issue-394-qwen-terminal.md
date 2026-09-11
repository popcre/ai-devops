# #394 Qwen content-inspection terminal diagnostics

The recorded DataInspectionFailed incident became a generic failed state.
A provider-shaped offline reproduction confirmed `failed` where the stable
reason should be `content-filter`. The wrapper now recognizes the typed error
in result, assistant and stderr forms, including an assistant refusal followed
by a success-shaped terminal record. Every form remains unsuccessful.

Private stderr is retained alongside the pending response, and public failure
output contains a fixed explanation rather than the provider body. Existing
source, interruption, credentials, verdict and continuation guards remain.

Validation on 2026-09-11: `tests/test-ai-qwen.sh` passed 126 checks, zero failed.
The consumer mapping regression failed before repair (58 passed, one failed)
then passed all 59 checks, zero failed or skipped. Its bounded commit is
`4f6ce1c0ca9c59dc8f57b58b2d5647e6c4fa1b4f` in the consumer source-contract branch.

Recovery-path integration, exact-head independent review, CI, installation and
incident closure remain pending. This does not prevent provider-side filtering;
it reports that refusal accurately and preserves the paid diagnostic evidence.
