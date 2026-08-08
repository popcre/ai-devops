# Markdown document reachability

`bin/ai-doc-reachability` prevents a new or moved Markdown document from being
merged when no reader can find it from the repository's living root documents.
It is deliberately a pull-request gate, not a full legacy cleanup tool.

## The rule

A Markdown document is reachable only when a chain of real Markdown links leads
to it from a configured root such as `README.md`, `AGENTS.md`, `CLAUDE.md`, or
`HANDOFF.md`. Two unlinked documents pointing at each other remain an island and
do not pass.

The gate checks only Markdown paths that the pull request adds, copies, or
renames. Editing an old orphan does not fail the pull request. This keeps legacy
debt from turning the check red on its first day while still preventing new debt.

The checker ignores fenced code examples, inline code examples, bare URLs,
anchors, images, and links outside the repository. It supports ordinary inline
links, explicit reference-style links, URL-encoded paths, directory links that
resolve to a README or index, and extensionless links that resolve to Markdown.

## Repository config

Every participating repository commits `.doc-reachability.json` at its root:

```json
{
  "roots": ["README.md", "AGENTS.md", "CLAUDE.md", "HANDOFF.md"],
  "preferred_root": "README.md",
  "exclude": [
    "HANDOFF.d/**",
    "archive/**",
    "**/archive/**",
    "CHANGELOG.md",
    "**/CHANGELOG.md",
    "LICENSE.md",
    "**/LICENSE.md",
    ".github/**"
  ]
}
```

- `roots` lists the only documents where reachability may begin. Missing roots
  are fine as long as at least one configured root exists.
- `preferred_root` makes failure output concrete by showing the expected route.
- `exclude` contains repository-owned glob patterns for intentionally floating
  material. Exclusions are data, never hard-coded into the checker.

Do not exclude ordinary product or engineering documentation merely to silence
the gate. Archive material belongs under an honest archive tree with a short
README explaining what it contains.

## Enable the blocking pull-request check

Add this workflow file to the participating repository:

```yaml
name: Documentation reachability
on: pull_request
jobs:
  docs:
    uses: u2giants/ai-devops/.github/workflows/docs-reachability.yml@main
```

That single `uses` line calls the shared workflow. The workflow checks out the
exact pull-request head and compares it with GitHub's exact pull-request base
SHA. It fetches full history so rename detection and the merge-base comparison
are reliable. A missing base or config is an error, not a guessed fallback.

Make this job a required check in the repository's branch rules. The workflow
returns a non-zero status for every unreachable added or moved document.

## Fix a failure

The report names the unreachable file and shows an expected route such as:

```text
Expected route from root: README.md -> ... -> docs/new-finding.md
```

Add a descriptive link from the root's real navigation section or from an
existing reachable topic index. The link text should say why a future reader
would open the document. Do not create a catch-all page containing every file.

If a dated finding corrects current guidance, update that living guidance in the
same pull request. A link makes the finding discoverable; it does not repair a
living document that still teaches the wrong rule.

## Local use

Compare the current branch with an explicit base commit or ref:

```bash
python3 bin/ai-doc-reachability --repo . --base origin/main
```

The checker refuses to guess a base outside a pull-request event. This prevents a
local default branch, stale tracking branch, or merge commit from silently
changing which files are judged new.

Run the regression suite with:

```bash
python3 tests/test-ai-doc-reachability.py
```
