# Qwen rotation restore — 2026-09-16 (EDGE-DEV)

### Qwen was listed but not usable

What changed:
Qwen stayed `registered` in `config/reviewer-registry.json` while
`ai-review-preflight status qwen` reported `usable=false` with
`failure_class: live-qualification-required`. The official standalone runtime
was missing. An npm `qwen` 0.23.0 was on PATH; the wrapper does not accept it.

Why:
Live qualification is bound to the exact wrapper, runtime, and preloader
hashes. Those no longer matched, and `resolve_qwen` only accepts the vendor
standalone (`%LOCALAPPDATA%\qwen-code\bin\qwen.cmd` on Windows). The Windows
installer treats any resolvable `qwen` as present, so a bare reinstall skips
the standalone.

Future sessions should:
1. Trust `ai-review-preflight status qwen`, not registry membership and not
   `bugs.md` finding 12/16 as they stood before this date.
2. Restore with
   `bin/install-windows-ai-provider-clis.ps1 -SelectedProvider qwen -QwenVersion v0.23.0`
   then `ai-qwen doctor --live` and `ai-review-preflight qualify qwen`.
3. Not point `AI_QWEN_BIN` at the npm shim.

### 2026-09-16 proof (this host)

What changed:
Official Qwen Code 0.23.0 standalone was installed and child-secret hardening
was reapplied. Qualification succeeded. Status became
`installed-healthy` / `registered` / `usable=true`. A governed review of a
planted inverted `is_even` (`return n % 2 == 1` vs a docstring that requires
even) returned `VERDICT: REJECT f3aa8eb23ee739d4f8c5b5238520791cb65d217a`
on requested and returned model `qwen3.8-max`. The throwaway canary clone was
removed after the report was preserved locally; it was never pushed.

Why:
Albert required a valid and correct review before returning Qwen to rotation,
not only a live probe of `OK`.

Future sessions should:
Re-qualify on this host after any wrapper, runtime, or preloader hash change.
Do not copy this host's qualification file to another machine.

Unknown / verify live:
Whether other Windows hosts still have the standalone. Check
`ai-review-preflight status qwen` on that host; do not inherit this proof.
