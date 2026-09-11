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

Kimi terminal integration, consumer allocation agreement, exact-head independent
review, required CI, merged installation, live acceptance, and affected private
incident reconciliation remain pending. This file does not close #396.
