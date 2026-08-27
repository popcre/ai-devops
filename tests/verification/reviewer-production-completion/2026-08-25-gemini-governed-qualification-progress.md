# Gemini governed qualification progress — 2026-08-25

Repository-safe evidence for the governed Gemini qualification implementation
and the remaining production closeout. This note records an in-progress state;
it does not claim Ubuntu qualification or issue #38 completion.

## Source and verification

- GitHub `main`: `f26d5eb3b13ce6a01f2f61a262ef02e5b0016a2a`
  (`fix: validate Gemini qualification with local identity`).
- Targeted verification: `tests/test-ai-gemini.sh` 62 passed, 0 failed;
  `tests/test-ai-review-preflight.sh` 51 passed, 0 failed.
- Independent exact-source final review: APPROVE with no blocking findings;
  113 bound checks passed. Report:
  `.ai/reviews/codex-final-check-20260825T193706-749378-23914.md`.
- The single post-APPROVE master gate passed: 53 Bash suites and 16 PowerShell
  suites, zero failures. Do not repeat it for this source.
- Exact-head GitHub Actions run `32891794146` completed successfully: Linux
  offline, Windows reviewer-safety, and Windows offline all passed. Run URL:
  https://github.com/u2giants/ai-devops/actions/runs/32891794146

## What the final repairs changed

The governed record binds the exact `bin/ai-gemini` bytes, `agy` executable
bytes and version, configured model, provider, and qualification epoch. Failed
requalification revokes old authorization, identity is checked before and after
the canary, and local identity is revalidated immediately before every provider
execution. Generic live preflight now performs the real canary.

Two cross-platform defects were found during production qualification and fixed:

1. Commit `8776d47` stopped qualification identity from depending on the normal
   `agy models` call, which can hang even when the local executable identity and
   authenticated canary are usable.
2. Commit `f26d5eb` made qualification-record validation use local
   `doctor --identity`, preventing ordinary doctor/model discovery from blocking
   an otherwise valid record.

Commit `817f806` also changed CI concurrency to immutable event plus commit SHA,
so later normal `main` work does not cancel verification of this exact source.

## Machine state

| Machine | Source/status | Evidence |
|---|---|---|
| Windows `edge-dev` | `f26d5eb`; `available` | Governed live qualification passed and wrote a current machine-local record. |
| Ubuntu production | older installed source; `quarantined` | Earlier containment canary passed, but the current governed record has not yet been produced on `f26d5eb`. |

This is intentionally fail-closed: Windows can operate without waiting for
Ubuntu, while Ubuntu cannot inherit Windows qualification or an older record.

## Remaining release gates

1. Install current `main` on Ubuntu as user `ai`, verify source/manifest hashes,
   and confirm Gemini is quarantined before qualification.
2. Run Ubuntu's own governed Gemini qualification and require `available`.
3. Run one real Gemini review of open issue #38 and require a durable exact-head
   report with a truthful terminal verdict.
4. Update final plan/bug evidence, comment on and close issue #38, retire the
   superseded Gemini handoffs only after all obligations are retained, commit and
   push the closeout documentation, and require its CI to pass.

Gemini must not be described as fully production-qualified across Windows and
Ubuntu until every item above passes.
