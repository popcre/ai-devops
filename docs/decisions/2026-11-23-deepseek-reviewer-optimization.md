---
summary: DeepSeek reviewer and second-opinion optimization decisions from 42 live matched-pair trials (PR #2780).
kind: decision
status: current
read-when: Changing DeepSeek reviewer routes, caching, reasoning effort, context limits, or ask-deepseek defaults
---

# DeepSeek Reviewer & Second-Opinion Optimization (2026-11-23)

## Decision

Keep the current DeepSeek OpenRouter route (`deepseek-openrouter`), default reasoning effort, and opt-in-only cache flag (`AI_REVIEW_CACHE` off by default), while shipping the four safe fixes landed in [PR #2780](https://github.com/popcre/ai-devops/pull/2780) ([commit `5817f83d`](https://github.com/popcre/ai-devops/commit/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e)):

1. **Disable `session-title-llm` in DeepSeek Harness (`dsh`) headless config.**
   In [tools/reviewer_routes.py](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/tools/reviewer_routes.py), `harness_patch_yaml` now adds `session-title-llm` with `disabled: true`.
   In live matched-pair testing (Wave 1, 6 pairs), `dsh@0.2.2-rc.1` under `--profile headless` otherwise fired an extra non-DeepSeek LLM call per review. Disabling it cut OpenRouter requests from 52 to 34 (matching the exact 34 `dsh` steps) and lowered total spend from `$0.027607` to `$0.017313` (37.3% cost reduction), with `6/6` usable reviews in both arms and 100% seeded defect recall (`defect-early`, `defect-security`, `defect-late`, `real-711d33da`).

2. **Record `deepseek-harness` usage and cache-read receipts.**
   Added `status` `step_start`/`step_end` parsing for `engine == 'deepseek-harness'` in [tools/reviewer_usage.py](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/tools/reviewer_usage.py) and `harness_cache_receipts` wiring in [bin/ai-review-simple](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/bin/ai-review-simple), keeping missing counters distinct from zero.

3. **Align DeepSeek model context and output limits with live model capacity.**
   Live `https://api.deepseek.com/models` reports `context_window: 1048576` and `max_output_tokens: 393216` for both `deepseek-flash` and `deepseek-v4-pro`. Updated [bin/ai-review-simple](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/bin/ai-review-simple) (`PROVIDERS["deepseek"]`) and [config/opencode-deepseek/opencode.json](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/config/opencode-deepseek/opencode.json) to `1048576` context / `65536` output.

4. **Make default `ask-deepseek` invocation use DeepSeek Harness cleanly.**
   Updated [skills/shared/ask-deepseek/SKILL.md](https://github.com/popcre/ai-devops/blob/5817f83d97f79a153bffd1d3bb4ba2daf9cfd77e/skills/shared/ask-deepseek/SKILL.md) to omit `--repo-tools` from the default `ai-deepseek-agent send` example and document default Harness behavior. Note: `bin/ai-deepseek` (OpenCode implementer) already gets ~99% DeepSeek automatic prefix cache hits across steps and across fresh-process `ask` turns without changes.

## Rejected Candidates (Do Not Redo Without New Evidence)

Evaluated across 42 matched live reviews plus multi-turn recall checks on 2026-11-23:

- **Enabling `AI_REVIEW_CACHE=1` by default for DeepSeek (rejected):**
  Wave 2 (6 pairs, `title_off`): `dsh`/`pi-ai` already sends a fresh per-session `x-session-id`, achieving 91% within-review cache hits (`1,510,272 / 1,659,676` tokens) and costing `$0.031948` total vs `$0.052028` for shared-affinity `x-session-id` (both `6/6` usable). Shared affinity can also perturb endpoint selection and hurt usable rate in multi-host trials. Keep `AI_REVIEW_CACHE` opt-in.

- **Raising DeepSeek reasoning effort to `high` by default (rejected):**
  Wave 3 (6 pairs, `title_off`): `reasoning: high` took `400.4s` vs `102.9s` baseline (3.9x slower), cost `$0.122640` vs `$0.049372` (2.5x costlier), caught zero additional defects, and still false-flagged `REVISE` on `clean-retry`.

- **Switching default review/second-opinion route from OpenRouter to Direct DeepSeek API (`api.deepseek.com/anthropic`) (rejected):**
  Wave 3 (6 pairs, `title_off`): Direct API achieved `5/6` usable (timed out at `413.4s` on `real-711d33da`) vs `6/6` on `deepseek-openrouter` (`30/30` usable across Waves 1–3), ran 5.7x slower (`582.3s` vs `102.9s`), and cost `$0.021649` off-peak / `$0.043298` peak vs `$0.009883` on OpenRouter across the 5 completed small cases (plus `$0.001052` off-peak / `$0.002104` peak vs `$0.000521` on the 3-turn recall test).
