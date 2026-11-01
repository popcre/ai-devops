# TokenEconomizer isolated qualification receipt

Owner: Codex chat `01a194ee-7e16-70b3-9ebd-307fdd653f15`, [#2220](https://github.com/popcre/ai-devops/issues/2220).
Parent: [#2227](https://github.com/popcre/ai-devops/issues/2227).
Source: [pinned upstream](https://github.com/microsoft/TokenEconomizer/tree/c53a4a6dcdebaeb9df6fcaa5c7026f0401cd8f23),
version 0.1.0, Apache-2.0, Python >=3.10, standard-library-only runtime.
No vendor code was edited or copied into this public toolkit.

## Source/privacy qualification

The pinned `plugin/scripts/te_bootstrap.py` resolves the package; `hooks/*.json`
declares native events; `tokeneconomizer/plugin/{controller,hosts,fold}.py`
handles them. State root is the supported `TOKENECONOMIZER_HOME`, not implicitly
the agent's profile. Repository identity can join worktrees/clones with the same
origin, so a separate checkout alone is not isolated state. Pending folding reads
recorded session paths; never expose ordinary session archives to the experiment.

Defaults enable tool pruning and advisory loopguard. Set supported controls
before the first hook: `TE_TOOLPRUNE=off`, `TE_MICROSKILLS=off`,
`TE_LOOPGUARD=off`, `TE_REPOMAP=off`. For the separate facts arm use
`TE_MICROSKILLS=envfacts`; for the loop arm use `TE_LOOPGUARD=nudge` with facts
off. There is no independent invented envfacts switch. No forced termination,
proposer or repository map belongs to these arms. Sidecalls use native clients
and `TE_SIDECALL=1`; the entrypoint excludes their hooks. Digests can leave the
machine through native model calls: local state is not a no-egress guarantee.

Focused pinned upstream environment-facts/config tests passed (39 tests).
Additional focused hook, state/repository and ledger suites passed with one
upstream skip. Their synthetic fakes support the source audit; they are not
native desktop, original-capability or all-adversarial acceptance receipts.
No toolkit managed installer or new fixture harness was built before a useful
native smoke. Keep the larger step-2 tests/integration open.

## Actual native preflight

Ubuntu edge-dev3, October 31, 2026. Claude Code 2.1.309 is within the pin's
2.1.300–2.1.310 range. An empty task-owned `CLAUDE_CONFIG_DIR` contained only a
protected copy of existing subscription login state before native startup.
`claude auth status` reported authenticated, but that status was insufficient.
The native invocation used `--plugin-dir` pointing to the immutable public
source, empty setting sources, strict MCP configuration and noninteractive
permission refusal. The supported plugin-directory route is session-scoped;
no global marketplace installation or ordinary-profile mutation occurred.
All four mechanisms were off before the first hook and the optimizer state
root was a separate empty task-owned directory. Only a synthetic public file
was in the task directory. Reader calls/state were never supplied to this profile.

The stream recorded native `SessionStart:startup` hook start and a successful
hook response. Native initialization identified tokeneconomizer 0.1.0 inline
and model `claude-opus-5-5`. Then the actual model call failed:
`Failed to authenticate: OAuth token revoked. Please log in again or contact your administrator.`
Exit 1; result had `is_error=true` despite subtype `success`. No successful
tool event, recovery, learned fact, redirect or desktop notice is claimed.
Reported inference tokens and per-request cost were zero for this failed call;
that is not a zero-overhead or savings result. Setup/author overhead is unknown.

The original credential file was byte-identical to its protected copy: the
failure was not repaired by refreshing an unchanged file. Native subscription
reauthentication was attempted without changing provider, model or billing.
The existing-account Google sign-in popup repeatedly timed out on native input;
a fresh browser tab progressed through existing-account consent but did not
complete the original callback. Authentication repair is unproved. Do not ask
Albert to operate it or claim a sign-in/status response is a live model proof.
The original profile/configuration and its existing capabilities were not
removed or replaced. Claude authentication remains an explicit capability gap.

Codex 0.166.0-alpha.5.1 is newer than the pin's verified range ending 0.164.0.
Its ordinary no-history read-only model/tool probe succeeded independently of
the optimizer. That does not qualify this plugin or authorize a downgrade.
No Codex optimizer hook/trust proof is claimed.

A proposed temporary Codex plugin installation was not performed: the deployment
gate refused the then-uncommitted candidate (`Candidate checkout has local changes;
install only an exact committed target.`). No plugin add/trust command followed
that refusal. Public receipt delivery is a separate source-only action; it
does not authorize or bypass that installation boundary.

## Disposition and same-issue acceptance

Blocked native optimizer smoke, not rejected efficacy and not desktop success.
The coordinator owns auth repair plus native desktop access on #2220. Before
dependent paid pairs, establish actual working native events/model access and
the privacy/isolation/recovery gates. Then follow the frozen
[measurement schedule](measurement.md) and current [applicability](applicability.md).
No managed installation, rollout, percentage saving or completed benefit gate.

- [ ] Native isolation/privacy and original edit/test/MCP/skill capability proof.
- [ ] Advisory loopguard and LLM-free facts smoke, with warm-up costs included.
- [ ] Current native desktop proof/disposition for all requested combinations.
- [ ] Ten-pair study and installation only for useful, accepted native targets.
- [ ] live proof remains on #2220; no duplicate blocker/proof issue.
