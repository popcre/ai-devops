# #396 scoped admission backoff

Owner: reviewer programme #337. The existing preflight quarantine store now
holds version 2 records: the original global health quarantine and independent
profile/model refusal observations. Legacy version 1 records migrate without
losing the health quarantine. This extends the existing owner rather than
adding another service or store.

`tools/reviewer_admission.py` owns atomic publication and crash-released OS
locking. Preflight owns the public interface and applies the same scoped policy
to `check` and `usable`. Kimi scope uses its existing opaque home-path hash and
model; no credential is read or hashed. Unscopable observations are refused.

A terminal usage-limit observation retains its evidence digest, source run,
observation epoch, and policy expiry. Replaying the same observation does not
extend expiry; conflicting evidence for that run refuses. Local failures and
busy workers cannot create a usage-limit backoff. Policy expiry does not claim
that quota has reset: quota remains unknown and the authoritative capacity
interface is unchanged.

Initial local verification: seven Python behavioral cases passed, including
scope isolation, fake-clock expiry, replay, invalid/stale evidence, legacy
migration, eight concurrent writers, and killed-lock-owner recovery. The full
preflight suite passed 92/92. Its matching-scope assertion was then strengthened
to require healthy install plus scoped refusal rather than relying on an exit
code; the strengthened focused scope suite then passed seven assertions with
zero failures, including the seven Python cases through its first assertion.

The shared `effective-profile kimi` interface resolves ordinary home overrides
and the existing root-to-owner review delegation from bounded, non-generating
provider discovery and the target account's actual login environment. It never
assumes `/home/<name>`. Allocation and dispatch use this same context; delegated
dispatch pins the resolved credential home. Target runtime canaries run as that
account without changing permissions or exposing root state. Implementation
remains non-delegating. A context-discovery timeout refuses before a paid call.

Kimi integration at `ac8ab53f` passed 234 owning-suite cases and 22 focused
admission cases. Independent review identified three follow-ups: delegated
scope coverage, optional evidence-hash failure, and provider-prefixed stderr
refusals. The final corrected focused integration passed 30 cases, including
target scope/refusal replay prevention, relative target-home resolution,
retained finalization after hashing failure, unchanged implementation refusal,
and zero-provider context-timeout refusal. The full preflight suite passed
92/92 after shared effective-context integration; all nine Python store cases
passed after canonical home publication.

Final delivery completed on 2026-09-11. Independent Muse review approved exact
PR head `ce97c710578e1b693f763e18df7ba3227027bf54`. PR-head CI run
`34646058019` passed Linux, all four Windows offline sections, the start
deadline, the designed primary-job cancellation, its fallback, and the
aggregate gate. Merge-group run `34650896712` passed on the exact landing tree;
PR #416 merged as `a031c1de77a11bbf16fe5be8699d78dfdc6233e9`.

The canonical installation and machine-tools doctor passed. Installed source
SHA256 values were `1D914059A5998119F4DEF433EA5E0E86CD5414631FE7466F02F2A1F7B6E3B20C`
for `ai-kimi`, `0ADCB660C5F2C200666AEDCC5E0DD72BF756BD21169D130476C66FD353FC2FB6`
for preflight, and `E6EE15E0DD1887ACB18F6085B1EF6F77814B750D0F6A9AC1AF24B1488AF061EB`
for the admission store. Installed live proof showed same-scope backoff,
unchanged replay expiry and digest, different-scope eligibility, eight
successful concurrent scoped observations, and guarded eligibility after
expiry. Quota and reset remained unknown; no provider request or credential
read occurred.

Two affected private incidents are resolved and one is partially resolved: a
first unknown Kimi call can still encounter a genuine five-hour provider limit.
That residual has permanent carry-forward evidence. Three frozen candidates
were classified without changing the database boundary. Round
`0c62f3dffce145c4b2768855b912b958` remains active with all 198 candidates:
36 incident and 162 unclassified. #398 remains last inside #337 and #166 last
inside #159.
