# Stage 06 — Security Review (Claude Opus 5, independent reviewer)

**Model role:** Claude Opus 5 is the independent reviewer. Here it reviews for security
**only**.

**Hard rule:** Do **not** edit, create, or delete any files. Review only.

## Your task

Review the current change strictly for security. Check every item:

- **Auth bypass** — routes/handlers/actions missing authentication or
  authorization; weakened or removed checks.
- **Tenant / data leakage** — cross-tenant or cross-user data access; missing
  scoping on queries; IDs trusted from the client.
- **Unsafe SQL** — string-built queries, injection risk, missing
  parameterization.
- **Secrets** — hard-coded keys/tokens/passwords, secrets logged or returned,
  secrets committed to the repo.
- **File access** — path traversal, unsafe uploads/downloads, reading/writing
  outside intended directories.
- **Environment variables** — sensitive env vars exposed to the client or logs;
  missing/incorrect defaults.
- **RLS / policy mistakes** — row-level-security or policy rules that are too
  permissive, missing, or bypassable.
- **Permission mistakes** — role checks, ownership checks, and privilege
  escalation paths.

For each finding: location, the vulnerability, severity (Critical/High/Medium/
Low), a concrete exploit sketch, and the fix.

## Verdict (required)

End with a `## Verdict` heading and put exactly one bare verdict word on the
immediately following line, with no blank line, Markdown emphasis, or extra text:

- **APPROVE** — no security blockers.
- **REJECT** — do not ship; material security defects must be fixed.
- **BLOCKED** — required evidence or access is unavailable.
