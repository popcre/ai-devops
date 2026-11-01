# Oracle offline alternate serialization — closed source capability

Owner: Oracle coordinator on u2giants/theoracle #27/#58. This source capability
does not claim installation, current-purpose registration, private execution or
source/business acceptance. New shared helpers exist only for this named
profile; retire them through reviewed source when this serialization purpose is
reconciled, preserving historical lifecycle/spent evidence.

## Descriptor-only admission (no reviewer verdict)

Owner rulings 2026-10-29 ("reviews advisory"; "reviewers preferred, never
required") retired the reviewer registrar (#2041). No reviewer APPROVE,
lifecycle record, report line or verdict is required or read anywhere on this
route. An AI review of the action stays optional advisory evidence: when
`--reviewer-approval <report>` is passed, only its SHA-256 is recorded in the
admission as `advisory_review_report_sha256`.

Root prepares fresh metadata/stat observations and historical claimed hashes
without opening captures, and publishes the descriptor with the existing
exclusive metadata publisher. Root declares the Oracle task `private-tooling`
and runs:

```
ai-task-gates check --before offline-private-capture-transform --action-manifest-stdin < oracle-native-action.manifest.json
```

The gate opens only for `u2giants/theoracle`, declared and effective class
`private-tooling`, initial-forward stage, no `--acknowledge` or small-owner
entry, and the committed local opt-in gate that matches the descriptor's
profile (`oracle-native-alternate-descriptor-only-admission` for v1,
`oracle-native-alternate-v2-descriptor-only-admission` for v2). The profile
tool's `admit` phase then requires, without reading any capture bytes:

- a clean committed Oracle checkout (`working_tree_sha256` of empty), its exact
  canonical origin, every public closure path present at HEAD, and the
  descriptor's `source_head`/`source_digest` equal to that source identity;
- for v2, the frozen public contract and three code pins at HEAD;
- the truthful `ai-task-gates explain` classification and committed opt-in;
- the complete stat-only descriptor contract: schema, census, fixed control
  roles and commitments, 33 pages, owned private single-link inputs, no
  duplicate inodes, size bounds, fresh output leaf, current custody with no
  unsupported external registrar, observation and expiry windows, the fixed
  public `/usr/bin/bwrap` identity and the verified public runtime closure;
- the installed enforcement identity (`VERIFIED_INSTALLED_SOURCE`) with the
  installed Oracle guard bytes equal to committed source.

It writes one exclusive 0600 admission at
`~/.local/state/ai-devops/oracle-native-alternate-admissions/<profile>/<action_id>/`
(expiry at most 300 seconds, never past the descriptor). A second admission for
the same action refuses. The task records a `native-admission` override with the
admission digest. Test mode can admit only a `NONAUTHORIZING_TEST_FIXTURE`
admission, which the guardian refuses to consume.

## Execution boundary

`ai-oracle-native-alternate --admission <admission file>` re-derives the
binding from the clean committed source and descriptor and requires it to equal
the admission. It atomically consumes one durable spent marker
**before the first content-capable capture open**. Failure/crash leaves it spent;
there is no automatic retry or refresh. An admission lasts at most 300 seconds
and needs at least 180 seconds of remaining scope. Metadata/
custody observations are at most600 seconds old, never future observations.
The guard uses a monotonic deadline and rejects wall-clock divergence over2
seconds or registration movement/revocation.

The public OS/stdlib runtime preparer creates a **NONAUTHORIZING** recipe from
root-owned system package bytes only. It reads no capture, installs nothing and
creates no permission. Preaction checks its complete allowed file inventory and
actual public origins and every staged PUBLIC runtime byte before approval/
consumption; retained capture/control/original bytes are not read by this check. No model assets/site-packages/private
home or arbitrary callback are mounted. Namespace failures stop; no privileged
fallback or weakened limit exists.

The isolated worker reads each capture/control input once, verifies actual
hash/size and the strict historical custom page snapshot schema, preserves native
structure/provenance/Unicode addresses, and checks the full page/group census
before writing. Original binaries/qualified readings are not mounted or parsed.
Its only private-processing launch path is the installed native guardian; the
worker's namespace checks are defense in depth, not an authority issuer or a
standalone permission API. In-memory codec tests grant nothing.

Maximum aggregate runtime/input256MiB, aggregate output256MiB, one worker,
at most two threads,8GiB address space,120CPU seconds,180wall seconds; network
and host sockets absent. Fresh outputs0700/files0600, no overwrites/symlinks.
Source/schema/hash/clock drift stops with unqualified partials retained. Only
sanitized hashes/counts leave the worker. `source_qualified` and `ledger_adopted`
remain false; no SourceRef, provider, company-generation, hosting, ledger or
semantic/business permission is issued.

## Source verification

`tests/test-oracle-native-alternate-action.sh` proves real nofollow/stat privacy,
a real `ai-task-gates` descriptor-only admission with no review present,
refusal of bad/dirty/replayed descriptors, test-fixture consumption denial, current metadata/contract/
expiry, source/budget/custody neighbors, closed mounts and genuine local Linux
namespace/resource probes. The actual private action is never run by these tests.
Existing `tests/test-ai-review-action-profile.sh` and
`tests/test-ai-task-gates.sh` must preserve foreign770 and generic denials.
Oracle tests cover exact one-pass byte hashing/Unicode, metadata retention,
schema/hash/budget/expiry/census refusal and ordinary host invocation denial.
Root integrates the new operator tests into its mandatory W10 inventory and the
new toolkit helper/docs into repository routing after source review.

## Historical custom capture closure (supersedes unpublished full-document assumption)

The pinned public producer emits custom native page snapshots, never full DoclingDocument exports. The separate native_page_alternate module consumes this exact format; the existing full-document decoder remains independent and is not used by this action. Historical commits b47a05c5/42f0438 remain recovery evidence, not applicable capture admission.

A descriptor fixes 48 read-only inputs in this order: completion, configuration, producer, independent custody proof, original alias manifest, group inventory, page skeleton, eight group manifests (indices0–7), then33 page files in group/page order. Before any capture-page bytes, actual fixed control hashes are verified after durable action consumption, followed by completion→group→page hash/size/count chains and26 alias/8 original/33 page inventory checks. Historical original binaries, readings, models and receipt renewal are excluded. Per-file8MiB and aggregate runtime/input256MiB bounds apply.

Only captured native_text_region/table_cell source_text is concatenated verbatim in captured list order per native page; new offsets count UTF-8 bytes. Native IDs, bbox, charspan, structural links and cell row/column addresses remain distinct retained metadata. Native characters, literal byte ranges and pictures remain explicit unrepresented gaps, with their unsupported source text/alignment quotes excluded from alternate output. No supported captured text across the entire closure refuses without output. Capture-format or control-schema mismatch refuses; unknown historical fields are never guessed. The independently registered purpose/action digest binds this revised fixed public closure and actual format. Current metadata lookup has located candidate historical files but validates no bytes or historical hash. Actual admission/installation/review remains root-owned.

## Sandbox and persistence hardening after independent rejection

The manifest cannot select an executable. Only /usr/bin/bwrap is supported, with nofollow traversal, root-owned nonwritable parents, a root-owned regular unaliased binary and its actual public OS SHA. The sanitized independent review evidence includes that fixed public identity, runtime closure hash/bytes, exact input format and all resource bounds; it exposes no capture paths or text. Namespace confinement remains a real platform gate, not a claimed approval.

Every additional Oracle review attachment has the same complete canonical-realpath check as existing attachments. Receipt locks require current ownership,0600 and one link. The persisted task override must match the entire provider/implementer/run/mode/head/report/action summary and private-tooling class; matching a report-hash substring grants nothing. Native gate admission must return the same preapproval summary and pass persistence readback before and after publication. After the durable one-use claim, every opened input descriptor must retain its full device/inode/uid/mode/size/mtime/ctime and one link. Runtime staging directories explicitly use0700 even under permissive umask. The OS owner/root remains a trusted custody boundary; a worker namespace alone is defense, not registration or replay protection.

## Independent PUBLIC runtime verification before any private action

Preapproval may read staged PUBLIC runtime files and live public OS origins. This
is distinct from retained capture/original/control inputs, which stay unopened
until genuine one-use action consumption. The complete Python/stdlib/library
source set is independently derived from the live root-owned nonwritable OS,
not selected by the recipe or a caller hash. Every staged file must match that
live origin's actual length/hash, and every placeholder is fixed empty. An
operator-recomputed closure cannot admit a trojan stdlib or substitute origins.

Traversal uses anchored nofollow directory/file descriptors, complete stat
checks and regular unaliased nodes only. Symlinks, FIFOs, sockets, devices,
unknown files and extra directories refuse before claim/private opens. The fixed
root-owned /usr/bin/ldd is hash-verified before each bounded clean-environment
execution; arbitrary tools/substitutions refuse. Sanitized evidence binds the
live OS origin-set hash, ldd identity and actual runtime closure. Unknown
repository identity refuses this action explicitly; admission-file publication
fsyncs its parent directory. Existing spent marker collisions still deny and
preserve the old marker; there is no retry, renewal or replacement.

The exact already-public producer document/pin remains immutable. Its public
path is not reclassified as a secret, and generic/private Markdown remains
refused. Mutable private artifacts are never scrubbed/promoted into review code.
