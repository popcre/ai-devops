# New Application Checklist

Use this as the compact checklist behind Albert's new-application prompt.

## Principles

- Albert is not the sysadmin; take ownership of code, repo setup, CI/CD,
  deployment, docs, verification, and handoff.
- Ask for access once, before implementation.
- Prefer boring, maintainable architecture.
- No secrets in repos, docs, prompts, screenshots, or transcripts.
- GitHub is source of truth for code and workflows.
- Deployment platform owns runtime config.
- Production host is a runtime host, not a place to hand-edit app state.

## Required outputs

- Working app code.
- Tests and local verification command.
- Standard markdown docs.
- CI/CD workflow.
- Deployment docs and runtime config map.
- Verified live deployment when deployment is in scope.
- Handoff only if unfinished.
