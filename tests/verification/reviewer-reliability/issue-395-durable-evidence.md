# #395: durable reviewer evidence and interruption provenance

Owner: reviewer programme #337. This repair preserves review safety and makes
the evidence needed to explain a failed or interrupted review survive cleanup,
races, stale state, and binary patches.

## Delivery acceptance, 2026-09-11

The five exposed CI regressions were repaired without removing a provider or
weakening ordinary verification. GLM now durably reserves and publishes partial
evidence, Grok doctor publishes its evidence durably, Kimi and Qwen archive the
correct stale-head evidence, and the retired historical recorder remains
verifiable. The retained packet verifier checks seals, schema, manifests,
ordinary and binary patches, and multipart recovery.

Focused results were GLM 74/0, Grok 234/0/0, Kimi 220/0, maintenance 97/0 with
four platform skips, and packet verification 114/0. Exact-head Muse review
approved the final merge candidate; its report hashes to
`d446784ac70a198916eb2cfd97a825b647338d30e6d1828151e12f404d17babe`.
Branch CI run `34627124091` passed Linux, all Windows sections and aggregate,
and the designed fallback after the bounded primary lane ended. The change
merged as `972d03b601dd18815627e1d268f3a7375516820b`.

The installed private recovery probe removed the source review directory, then
recovered the exact report and binary patch with matching hashes from durable
evidence. It made no provider request. All 33 ambiguous records in frozen round
`0c62f3dffce145c4b2768855b912b958` are preserved as incidents and now reference
the merge, CI, independent review, and installed proof. Their historical causes
remain explicitly unknown. The round itself is unchanged and stays open for
#398, which runs last inside #337; #166 remains last for #159.
