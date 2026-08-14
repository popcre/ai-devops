---
name: trigger-score-variance
description: "A skill trigger score swings several points across days with no text change, so one --runs 3 score is an observation, not a verdict; and a global naming a skill does NOT suppress it."
metadata: 
  node_type: memory
  type: project
  originSessionId: 8efc08d3-86fd-4cc2-b590-c87c04e93bf9
  modified: 2026-08-14T16:25:34.696Z
---

Measured on `synology-long-running-operations`, same committed eval set, same
`--runs 3`, no change to the skill text at any point:

| When / where | Should-fire | False positives |
|---|---:|---:|
| 2026-08-12, `al8960ofc` | 2/10 | 0/10 |
| 2026-08-13, `al8960ofc` (after the global started naming the skill) | 1/10 | 0/10 |
| 2026-08-14, `al8960ofc` | 5/10 | 0/10 |
| 2026-08-14, `hetz` (Ubuntu) | 10/10 | 0/10 |

Two conclusions, both of which overturn earlier write-ups:

- **A global that names a skill does NOT substitute for it.** The step-8 claim
  (and its "1Password precedent") is retracted in `docs/skill-trigger-eval.md`.
  Never move a skill's procedure into an always-loaded file on that reasoning.
- **A single score is not a fact.** The 4-point Windows swing with nothing
  changed is larger than any description edit ever measured, so the two
  description rewrites that step 7a "measured as failures" were never actually
  shown to fail. Do not revert a description on one run.

Stable across every measurement, on both platforms: **precision. Zero false
positives, always.** The failure mode is silence, never noise.

Open, nobody on it: the platform gap (Linux 10/10 vs Windows 5/10). Leading
explanation is that the neutral eval project has no Synology MCP wired up. Not a
safety issue — the 25-second NAS limit lives in the global and probes confirm
sessions state it correctly on both platforms.

Related: [[globals-machine-section-trap]].
