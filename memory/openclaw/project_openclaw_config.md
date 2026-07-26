---
name: OpenClaw config file locations and structure
description: Key config files for OpenClaw on the VPS and what each controls
type: project
---

All files live on the VPS at /opt/stacks/openclaw-team/data/.

**openclaw.json** — master config. Controls: which models appear in the UI (agents.defaults.models), which model the main agent uses (agents.list[0].model), gateway auth token, allowed origins, trusted proxies.

**agents/main/agent/models.json** — provider definitions. Controls: baseUrl, API type, and model list for each provider (anthropic, openai, google). Both this file AND openclaw.json must be updated to add a new model.

**compose.yaml** — Docker compose file at /opt/stacks/openclaw-team/compose.yaml. Contains all API keys as environment variables (ANTHROPIC_API_KEY, OPENAI_API_KEY, GEMINI_API_KEY, GOOGLE_API_KEY). Note: both GEMINI_API_KEY and GOOGLE_API_KEY are set to the same value — OpenClaw warns about this but uses GOOGLE_API_KEY.

**Main agent model** — currently set to anthropic/claude-sonnet-4-6 in agents.list. OpenClaw hot-reloads config changes without restart.
