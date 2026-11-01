# November 1 isolated native CLI smoke

Owner: Codex chat `01a194ee-7e16-70b3-9ebd-307fdd653f15` on edge-dev3.
Owning issue: [#2220](https://github.com/popcre/ai-devops/issues/2220);
coordination: [#2227](https://github.com/popcre/ai-devops/issues/2227).
Recorded November 1, 2026, 7:23 AM EST.
Related [schedule](measurement.md), [applicability](applicability.md),
[qualification](report.md) and [plan](../../../plan_tokeneconomizer-desktops.md).

## Verdict and boundary

Native CLI smoke completed; desktop acceptance remains blocked by this chat's
browser-only control surface. No managed installation, rollout or saving is
accepted. Loopguard produced useful advice. Facts learned/reused a synthetic
setting, but missed a required native test until a coordinator follow-up.
Native skill inventories differed between baseline/treatment, so even these
CLI pairs are not clean matched cost evidence. Do not extrapolate or silently
repeat/tune this bounded study. Preserve failures and all costs below.

Claude's revoked subscription OAuth was repaired through supported native
sign-in and existing-account browser authorization. A fresh native request
returned AUTH_OK, is_error=false, on claude-opus-5-5. Sign-in status alone was
not used as proof. No provider/model/billing change or credential disclosure
was required. Original working sign-in remains in place.

## Frozen synthetic controls

Upstream immutable pin: c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23,
TokenEconomizer 0.1.0. Native Claude Code 2.1.309; author model
claude-opus-5-5, medium effort. Native helper model claude-haiku-5-5.
Public synthetic source commit: 75f37525e865059a888dd3ab11b3896e2b4e8395.
Separate task-owned profiles, optimizer state and clones per arm; reader state
and personal archives were not supplied. Native auto-memory was off only in
these profiles. Ordinary profile hooks/settings/tools were not edited.
Session-local supported plugin loading only. Tool pruning, model proposer
and repomap stayed off. Loop treatment enabled nudge only; facts treatment
enabled envfacts only. Baselines loaded no optimizer.

Exactly five successful clean loop warm-ups populated resolved turns
[6,7,7,7,7]. Exactly four fact-learning sessions yielded an ACTIVE injectable
APP_SETTINGS=conf.dev fact, fire 4/4. No post-result threshold tuning or extra
learning sessions. Order: loop baseline, loop treatment; facts treatment,
facts baseline. Every task restored only the owned synthetic work.py bug.

The initial preflight hid the synthetic skill with empty setting sources in
both arms. Both failures are retained. Before learning/pairs, supported user
setting sources loaded the owned synthetic skill. The initial request to
disable caching was ineffective: native counters reported caching. Measured
runs used normal automatic native caching; never label them cold-cache.

Both pairs used the same harmless skill/MCP fixture and required read, edit
and unit-test checks. All 27 initialized tool names matched, including MCP.
Every baseline skill remained available in treatment, but treatment also
listed additional native marketplace skills. Their content/use was not
qualified. This inventory mismatch is a causal-comparison confound, not
evidence of complete capability parity. No additional skill was invoked by
the trial. Eight ordinary MCP connections were connected before and after,
with zero failures. This proves connectivity, not every real business journey.

## Native outcomes

Loop baseline made twenty separate failing checks, then edited only work.py
and passed its native check (75.47 seconds). Treatment issued advice after
eight failing checks, then edited only work.py and passed (40.23 seconds).
Native session 32052869-dc34-4187-b47d-7cbf5f78c5ae recorded one nudge,
zero aborts, one edit, resolved_proxy=true. Judge and writer were separate
native model sessions, not free local computation. No forced termination.

Facts baseline encountered one setup failure, inspected app.py, supplied
APP_SETTINGS=conf.dev, printed ran and passed the native edit/test task
(19.03 seconds). Treatment used the learned setting without that failure,
printed ran and edited correctly (23.64 seconds), but its test command with
an echo suffix was refused. It ended with test unconfirmed. An independent
coordinator test passed but did not count as native completion.

One explicit follow-up resumed the same facts session
54ad833c-a6c3-48ff-a39b-12ae3389d920. It ran the exact unit-test command from
the synthetic directory, returned Ran 1 test / OK with is_error=false
(6.83 seconds), without changing permissions, requirements or code.
This completed the task but does not erase the missed-check regression.

## Separate native list-price equivalents

USD figures are native subscription-usage list-price equivalents, not cash
charges. Native metrics-only OTLP export went to a temporary loopback collector;
no prompt/log/trace export. Cumulative counters were reduced by session,
attribute set and process route, with recovery counted once. In particular,
the resumed native result's cumulative $0.1552892 includes its earlier
$0.1346874; add only recovery's $0.0206018.

- Loop pair: baseline author $0.2214986; treatment author $0.1837070;
  judge $0.00075220; nudge writer $0.00046071; treatment total $0.18491991.
- Facts pair: baseline $0.0951112; treatment original $0.1346874;
  recovery $0.0206018; treatment complete total $0.1552892.
- Loop learning: $0.1659196, $0.1179840, $0.1994712, $0.0430810,
  $0.0436832; subtotal $0.5701390.
- Facts learning: $0.1854018, $0.1274084, $0.1273088, $0.0544636;
  subtotal $0.4945826.
- Failed skill preflights: baseline $0.1335498, plugin $0.0710388.
  Corrected preflights: baseline $0.1617348, plugin $0.1652910.
  Helper accounting probe: $0.000311525.
- Total measured native trial/preflight/helper usage: $2.253466435.
  Separate successful auth probe: $0.129524; combined known $2.382990435.
  Coordinator/author orchestration usage is unavailable, not zero.

Cache-aware native counters for each measured task, in order
input / output / cache-read / cache-creation:
- Loop baseline: 58 / 2918 / 473013 / 8538.
- Loop treatment including both helpers: 36 / 2318 / 289056 / 15935.
- Facts baseline: 14 / 1419 / 78696 / 6367.
- Facts treatment original: 16 / 1422 / 116357 / 10364;
  recovery separately: 6 / 265 / 44429 / 799.

No saving percentage is claimed. Learning/setup expense is retained, skill
inventories differ, and facts required intervention. Larger accepted study
still requires ten pairs per actual desktop installation, no additional
missed checks/capability loss, and >=10% lower total priced usage including
all optimizer overhead. One synthetic CLI pair cannot meet that standard.

## Live-proof checklist on #2220

Remaining native counters, same input / output / cache-read / cache-creation
order (learning/setup are retained, not free history):

```text
preflight-baseline            3458 1235  45539 17182
preflight-plugin              3782  977  58529  4933
sidecall-probe                 309   11      0  2201
preflight-baseline-corrected  7074  804  69269 20701
preflight-plugin-corrected    7398  826  70245 21026
facts-warmup-1                 16 1259  83709 17927
facts-warmup-2                 14 1241 109982 10067
facts-warmup-3                 12 1269  94604 10370
facts-warmup-4                 12 1185 103458  1253
loop-warmup-1                  10  865  50098 17320
loop-warmup-2                  10  872  67360 10879
loop-warmup-3                  10  863  61816 21226
loop-warmup-4                  10  847  81825  1217
loop-warmup-5                  12  868  81536  1246
```

Auth probe counters separately: 2 / 9 / 0 / 16167.

- [x] Repair revoked native subscription authentication; fresh model proof.
- [x] Fixed isolated CLI learning schedule; native loop advice and fact reuse.
- [x] Retain failed checks, recovery and separate measured helper costs.
- [x] Ordinary MCP connectivity and tested synthetic skill/read/edit/test retained.
- [ ] Actual Claude desktop coding engine, hooks, visible notice and recovery.
- [ ] Codex desktop supported current-engine plugin qualification and live journey.
- [ ] MiMo/ZCode actual desktop support or current supported inapplicability proof.
- [ ] Full original desktop capability/adversarial/restart/rollback proof.
- [ ] Per-installation matched ten-pair cost acceptance and managed rollout.
- [ ] live proof

The same coordinator retains the unavailable desktop access and acceptance
work on #2220; no duplicate ticket. #2227 owns isolation/coordination only.
#2222's reader pilot remains separate; its routine adoption was rejected.
No combined reader/optimizer adoption or cost claim. Entire task Trail
continuity remains unverified; GitHub is authoritative and capture stayed off.
