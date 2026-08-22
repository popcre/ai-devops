# Stage 07 — Final Product / Architecture Review (Claude Opus 5)

**Model role:** Claude Opus 5 performs the final product and
architecture review.

**Hard rule:** Do **not** edit files. Produce the final assessment only.

## Your task

Step back from the code and judge the whole change against the original request.
Answer each question directly:

1. **Does it satisfy the original business request?** Map the delivered change
   back to what was actually asked. Call out anything unmet.
2. **Did implementation drift from the plan?** Where and why? Does the drift
   matter?
3. **Remaining risks** — technical, security, data, product, or operational
   risks that still exist.
4. **Is it ready for PR / merge?** A clear yes or no, with conditions if any.
5. **Plain-English summary for Albert** — 3–6 sentences a non-programmer can
   understand: what changed, whether it does what he wanted, and what (if
   anything) he should watch out for.

Be candid. If it is not ready, say so plainly and list exactly what remains.

## Verdict (required)

End with a `## Verdict` heading and put exactly one bare verdict word on the
immediately following line, with no blank line, Markdown emphasis, or extra text:

- **APPROVE** — the requested outcome is complete and ready.
- **REJECT** — material product or architecture defects must be fixed.
- **BLOCKED** — required evidence or access is unavailable.
