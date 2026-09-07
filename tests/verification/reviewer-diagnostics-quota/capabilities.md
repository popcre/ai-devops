# Reviewer capacity capability matrix

Measured September 7, 2026 without submitting model work.

| Provider | Installed interface | Result | Scope and evidence |
|---|---|---|---|
| Kimi | Kimi Code 0.36.1 | Unsupported for automatic preflight | `kimi --help`, `kimi provider --help`, and `kimi doctor --help` expose no non-interactive usage command. Official Kimi CLI documentation describes `/usage` (`/status`) only as an interactive slash command for the Kimi Code platform. It has no documented structured response or headless subcommand. A prompt containing `/usage` would be a generation request and is forbidden here. https://moonshotai.github.io/kimi-cli/en/reference/slash-commands.html |
| Grok | Grok Build 1.0.13 | Unsupported | `grok --help` exposes agent, doctor, inspect, login, and local disk-usage commands, but no quota/capacity interface. The official source repository documents the CLI and links its command reference; no non-generating account-capacity contract is published. https://github.com/xai-org/grok-build |
| GLM | OpenCode 1.18.12 with `zai-coding-plan` | Unsupported | `opencode --help`, `opencode stats --help`, and `opencode providers --help` expose historical local token/cost statistics and credential management, not authoritative remaining plan capacity. OpenCode provider documentation describes model context limits, not account quota. https://opencode.ai/docs/providers |

All three production adapters therefore return `unknown` with zero network calls.
Unknown permits the existing guarded review path. Synthetic fixtures exercise the
validated `available`, `exhausted`, malformed, stale, and wrong-scope contracts
without credentials or generation. A future supported adapter must add official
response-schema, account/model scope, freshness, request-count, and non-generation
proof here before it may return `available` or `exhausted`.

Review dispatch paths mapped during qualification:

- Kimi: durable `start_review_job` and its worker `run_turn`; cancellation through
  `cmd_cancel_job`; terminal state through `review_worker` and cleanup.
- Grok: `cmd_new` and `cmd_ask`; both reserve exact work before `run_turn`, await
  structured terminal JSON, and retain uncertain paid-work locks on interruption.
- GLM: `cmd_new` and `cmd_ask`; `create_session` is non-generating, `send_prompt`
  starts generation, and `await_turn` owns bounded health/permission observation.
