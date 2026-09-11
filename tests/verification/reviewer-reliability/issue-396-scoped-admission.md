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

Final exact-head review, required CI, merged installation, live acceptance, and
affected private incident reconciliation remain pending. This file does not
close #396 or claim authoritative remaining quota.
