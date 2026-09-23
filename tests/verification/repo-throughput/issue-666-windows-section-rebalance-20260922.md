# PR #666 Windows section rebalance — 2026-09-22

## Observed failure

[Verify run 35536870288, Windows section 4 job 106147628858](https://github.com/popcre/ai-devops/actions/runs/35536870288/job/106147628858) ran on head `f50a33d52d8daa1c0169458ba3c84c914b5ab2d0`. Its log records `test-ai-gemini.sh took 681s`, then `test-ai-glm.sh took 1031s`, then starts `test-ai-muse-code.sh`. At 22:03:05 UTC the job reports `The operation was canceled`; it began at 21:22:56 UTC, near the unchanged 40-minute limit. Sections 1–3 succeeded in approximately 24–29 minutes. The run conclusion is `cancelled`, not a passing proof for PR #666.

## Assignment and preserved coverage

The three long suites now occupy separate sections 4–6 in `config/ci-suite-manifest.json`. Sections 1–3 retain their prior assignments. Every ordinary Windows Bash suite remains in exactly one section; the PowerShell owner remains section 3. `verify.yml` and the opt-in Blacksmith workflow both use all six declared sections. The hosted job bound stays 40 minutes; Blacksmith stays manual-only with its 20-minute bound. The independent qualified reviewer lane and the complete scheduled/manual backstop retain their previous routes and suites.

`tests/test-workflow-policy.sh` checks the full assignment union, distinct long-suite owners, both workflow matrices, and the manual Blacksmith boundary. `tests/test-windows-bash-selection.sh` checks that section mismatches, omissions, duplicates, and injected failures are refused. Local results on this source: workflow policy PASS; Windows Bash selection 48 passed, 0 failed. Exact-head GitHub CI and live duration remain acceptance gates.

## Follow-up from the first six-section run

[Verify run 35802300948](https://github.com/popcre/ai-devops/actions/runs/35802300948) passed all four Linux shards and Windows sections 1–4 and 6. Section 5 ran `test-ai-gemini.sh` alone for 668 seconds and failed one of 85 assertions: the synthetic `slow-pkt` case expected the packet-build timeout message. Its existing check suppressed the returned error, so the exact CI predicate cannot be recovered from that log. A local xtrace of the same unmodified test showed `slow-pkt` passing with return code 1, the expected packet-build message, and no session metadata; the sibling `slow-inv` case instead expired in packet verification before reaching the intended inventory stall. This demonstrates the class of timing race in the test fixture.

The fixture now precomputes the genuine source identity for only the three synthetic slow-stage cases and reuses it in the mock resolve/verify steps. Those cases still run their deliberate 60-second or 15-second stalls under the original 2-second per-stage bound, require the named timeout and no session metadata, and print their return code/output only on failure. Other test cases continue to exercise real identity resolution and verification.
