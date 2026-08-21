#!/usr/bin/env bash
# Offline tests for bin/ai-memory-health.
# The point of the tool is that it REPORTS and never edits, so the safety test
# (nothing on disk changes) matters as much as the detection tests.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/bin/ai-memory-health"
# Point the hub check at an empty directory so the real checkout's sync state
# cannot leak into these assertions.
PASS=0; FAIL=0
ok(){ printf '  ok   %s\n' "$1"; PASS=$((PASS+1)); }
bad(){ printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ if eval "$2" >/dev/null 2>&1; then ok "$1"; else bad "$1"; fi; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mk_project() { # mk_project <name>
  mkdir -p "$TMP/home/projects/$1/memory"
  printf '%s' "$TMP/home/projects/$1/memory"
}

mk_memory() { # mk_memory <dir> <slug> <description> [body]
  cat > "$2/$3.md" <<EOF
---
name: $3
description: "$4"
metadata:
  node_type: memory
  type: project
---

${5:-body text}
EOF
}

# --- clean project -----------------------------------------------------------
CLEAN="$(mk_project clean)"
mk_memory x "$CLEAN" alpha "the alpha fact about widgets"
mk_memory x "$CLEAN" beta "an unrelated note concerning payroll timing"
cat > "$CLEAN/MEMORY.md" <<'EOF'
# Memory index

- [Alpha](alpha.md) — hook
- [Beta](beta.md) — hook
EOF

out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"; rc=$?
check "clean project exits 0" "[ $rc -eq 0 ]"
check "clean project reports clean" "printf '%s' \"\$out\" | grep -q 'clean'"

# --- unindexed memory --------------------------------------------------------
mk_memory x "$CLEAN" gamma "a third fact nobody indexed"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"; rc=$?
check "unindexed memory exits 1" "[ $rc -eq 1 ]"
check "unindexed memory is named" "printf '%s' \"\$out\" | grep -q 'NOT IN INDEX: gamma.md'"

# --- broken index line -------------------------------------------------------
echo '- [Ghost](ghost.md) — hook' >> "$CLEAN/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "broken index line detected" "printf '%s' \"\$out\" | grep -q 'BROKEN INDEX LINE: MEMORY.md points at missing ghost.md'"

# --- dangling cross-link -----------------------------------------------------
printf '\nSee [[nowhere-at-all]].\n' >> "$CLEAN/alpha.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "dangling link detected" "printf '%s' \"\$out\" | grep -q 'DANGLING LINK: \[\[nowhere-at-all\]\]'"

# --- missing frontmatter -----------------------------------------------------
BARE="$(mk_project bare)"
printf 'just prose, no frontmatter\n' > "$BARE/loose.md"
printf '# Memory index\n\n- [Loose](loose.md) — hook\n' > "$BARE/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "missing frontmatter detected" "printf '%s' \"\$out\" | grep -q 'NO FRONTMATTER: loose.md'"

# --- missing index -----------------------------------------------------------
NOIDX="$(mk_project noindex)"
mk_memory x "$NOIDX" orphan "a fact with no index at all"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "missing index detected" "printf '%s' \"\$out\" | grep -q 'NO INDEX'"

# --- possible duplicate ------------------------------------------------------
DUP="$(mk_project dupes)"
mk_memory x "$DUP" first  "the supabase service account token rotated and every project reference broke"
mk_memory x "$DUP" second "the supabase service account token rotated breaking every stored reference"
printf '# Memory index\n\n- [First](first.md) — hook\n- [Second](second.md) — hook\n' > "$DUP/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "possible duplicate detected" "printf '%s' \"\$out\" | grep -q 'POSSIBLE DUPLICATE'"

# --- oversized index ---------------------------------------------------------
BIG="$(mk_project big)"
mk_memory x "$BIG" solo "one fact"
{ printf '# Memory index\n\n- [Solo](solo.md) — hook\n'; for i in $(seq 1 250); do printf -- '- filler line %s\n' "$i"; done; } > "$BIG/MEMORY.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" 2>&1)"
check "oversized index detected" "printf '%s' \"\$out\" | grep -q 'INDEX TOO LONG'"

# --- stale threshold is configurable ----------------------------------------
touch -d '2020-01-01' "$CLEAN/beta.md" 2>/dev/null || touch -t 202001010000 "$CLEAN/beta.md"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --stale-days 30 2>&1)"
check "stale memory detected at 30 days" "printf '%s' \"\$out\" | grep -q 'UNTOUCHED >30d: beta.md'"
out="$("$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --stale-days 99999 2>&1)"
check "stale memory not flagged at 99999 days" "! printf '%s' \"\$out\" | grep -q 'UNTOUCHED'"

# --- SAFETY: the audit must never modify anything ---------------------------
before="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" >/dev/null 2>&1
after="$(find "$TMP/home" -type f -printf '%p %s %T@\n' | sort | md5sum)"
check "audit changed nothing on disk" "[ \"$before\" = \"$after\" ]"

# --- --out writes a copy -----------------------------------------------------
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/home" --out "$TMP/report.md" >/dev/null 2>&1
check "--out writes the report" "[ -s \"$TMP/report.md\" ]"
check "--out report names the machine" "grep -q 'Machine:' \"$TMP/report.md\""

# --- bad usage ---------------------------------------------------------------
"$SCRIPT" --nonsense >/dev/null 2>&1; rc=$?
check "unknown option exits 2" "[ $rc -eq 2 ]"
"$SCRIPT" --repo-root "$TMP/nohub" --claude-home "$TMP/does-not-exist" >/dev/null 2>&1; rc=$?
check "missing projects dir exits 2" "[ $rc -eq 2 ]"

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
