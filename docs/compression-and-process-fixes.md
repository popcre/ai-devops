# Token-waste process fixes and compression trial

Decision record for the ScaleDown transcript audit (2026-10-14) and the A–F
process fixes. Read this before adding another token-saving tool.

## Measured evidence

ScaleDown processed **950** AI transcripts sampled from the private local
archive (8,702 eligible files). Text left the machine to ScaleDown only; raw
transcripts stay out of this public repository.

| Measurement | Result |
|---|---|
| Work mix | review ~50%, ops ~24%, coding ~14%, planning ~9% |
| Compress (120 samples) | kept **14.8%** of tokens on average (~**85%** cut) |
| Compress spread | 0.1% kept … 97.8% kept |
| Aggregate compress | 265,349 → 31,815 tokens |
| Dominant waste | verbose talk, redundant verification, repeated doc/status loads, logs pasted into chat |

**Headroom cross-check (do not skip).** A live Claude compression proxy
measured only **~2% net** token reduction on real coding traffic once
prompt-cache discounts are counted (`docs/headroom.md`). The 85% figure is
*redundant transcript material* compressed before an LLM call — not a budget
for every coding turn.

## When compression is allowed

- **Yes:** pasted or retrieved documents, boilerplate-heavy context, repeated
  rules/status blocks, before a *retrieval-style* question.
- **No:** secrets, private transcripts, review verdicts, code the model must
  write or edit verbatim, safety-gate evidence.
- **Measure:** billed tokens *and* cache hit rate. Raw size alone lies.

## ScaleDown compress API (the supported trial path)

- Base: `https://api.scaledown.xyz`
- Endpoint: `POST /compress/raw/`
- Key: 1Password `vibe_coding` → `scaledown.ai API key` (`op run` / `op read`;
  never print or commit).
- Body: `context`, `prompt`, `scaledown.rate` (`"auto"` or 0–1 keep/remove
  fraction per docs).

Optional local helper pattern (session temp, not a fleet install):

1. `op read "op://vibe_coding/scaledown.ai API key/credential"` into env.
2. POST the paste as `context` with a one-line `prompt`.
3. Use `results.compressed_prompt` in the next LLM call; record
   `compression_ratio` in the session notes.

## DietCode (not adopted)

DietCode (npm hooks + optional Claude proxy) was evaluated and **not installed**:

- Real history shrink needs their Claude-only proxy; hooks only add tokens.
- Must be measured against cache busts (Headroom lesson).
- Cursor path currently gets no automatic optimization.
- Revisit only with a one-machine, one-week paired measurement.

## Process fixes that landed (A–E)

| Fix | Where it lives |
|---|---|
| A Reply discipline / no empty blocks / status delta | Global rule files (`AGENTS-global-*.md`, `CLAUDE-global.md`, `~/.config/mimocode/AGENTS.md`) |
| B One status probe per state change | Global rules, `AGENTS.md`, `docs/development.md` |
| C Task packet for subagents | `templates/system/model-tier-delegation.md` |
| D Scratch-file size instinct | Global rule files |
| E PowerShell-safe quoting | `docs/development.md` |
| F Compression rules + this trial record | This doc + global rule line |

## Success checks

- Median reply length on routine turns
- No empty `Still open`
- Fewer API/door probes per landed PR
- Lower input tokens per child dispatch
- Fewer multi-kilobyte pastes in chat
- If compress is used: paired before/after billed tokens

Drop any lever that does not move its number.
