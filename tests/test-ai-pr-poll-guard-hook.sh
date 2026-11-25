#!/usr/bin/env bash
# Offline tests for bin/ai-pr-poll-guard-hook and bin/ai-install-pr-poll-guard-hook
# (plan_ruleset-trim-and-enforce.md step 2.1, #1881).
#
# The hook runs before EVERY Bash call, so "allows ordinary commands" matters as
# much as "blocks hand-written PR polling loops". The installer edits the user's
# settings.json, so "never corrupts it, never removes an existing hook" is the point.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/bin/ai-pr-poll-guard-hook"
INSTALL="$ROOT/bin/ai-install-pr-poll-guard-hook"
PASS=0; FAIL=0
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib-test-harness.sh"

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# Runs the hook on a Bash tool payload; prints the exit status.
fire() { jq -nc --arg c "$1" '{tool_name:"Bash",tool_input:{command:$c}}' | bash "$HOOK" 2>"$TMP/err" >/dev/null; echo $?; }
CASES=()
blocks() { CASE="$2"; CASES+=("$2"); check "blocks: $1" "[ \"\$(fire \"\$CASE\")\" = 2 ] && grep -q 'ai-pr-wait <pr> --timeout-minutes N' \"$TMP/err\""; }
allows() { CASE="$2"; CASES+=("$2"); check "allows: $1" "[ \"\$(fire \"\$CASE\")\" = 0 ]"; }

# --- every polling shape in the plan is blocked --------------------------------
blocks "sleep then gh pr view" 'sleep 60; gh pr view 12 --json state'
blocks "sleep then gh pr checks" 'sleep 30 && gh pr checks 12'
blocks "sleep then gh pr merge" 'sleep 120; gh pr merge 12 --squash'
blocks "sleep then ai-gh pr" 'sleep 45; ai-gh pr view 12'
blocks "until loop over gh pr view" 'until gh pr view 12 --json state -q .state | grep -q MERGED; do sleep 30; done'
blocks "while loop over gh pr checks" 'while true; do gh pr checks 12; done'
blocks "multi-line while loop" $'while :\ndo\n  gh pr view 12\ndone'
blocks "seq loop over gh pr view" 'for i in $(seq 1 20); do gh pr view 12; done'
blocks "timeout ai-pr-wait inside a loop" 'for i in 1 2 3; do timeout 600 bin/ai-pr-wait 12 --timeout-minutes 9; done'
# #1901: a loop handed to a child shell or eval is still a loop.
blocks "a poll loop inside bash -c" "bash -c 'for i in 1 2 3; do sleep 5; gh pr view 1 >/dev/null; done'"
blocks "a poll loop inside sh -lc" 'sh -lc "until gh pr view 1; do sleep 9; done"'
blocks "a poll loop inside eval" "eval 'while true; do gh pr checks 1; done'"
blocks "a poll loop inside bash with options" "bash --norc -o pipefail -c 'while :; do gh pr view 1; done'"
blocks "a poll loop inside ksh -c" "ksh -c 'until gh pr view 1; do sleep 5; done'"
allows "a quoted note passed to bash -c" "bash -c 'echo done'"

# --- ordinary commands are allowed ---------------------------------------------
allows "a single gh pr view" 'gh pr view 12 --json state'
allows "ai-pr-wait itself" 'ai-pr-wait 12 --timeout-minutes 9'
allows "ai-pr-wait with --fit-tool-call" 'bin/ai-pr-wait 12 --timeout-minutes 30 --fit-tool-call'
allows "a quoted commit message that mentions polling" "git commit -m 'stop sleep; gh pr checks loops'"
allows "a double-quoted note that mentions polling" 'printf "sleep then gh pr view\n" >> notes.md'
allows "a here-document that mentions polling" $'cat > notes.md <<\'EOF\'\nwhile true; do gh pr view 1; sleep 9; done\nEOF\nwc -l notes.md'
blocks "a loop after a here-document" $'cat > x <<EOF\ntext\nEOF\nwhile :; do gh pr checks 1; done'
blocks "a here-document fed to bash (#1901)" $'bash <<\'EOF\'\nwhile true; do gh pr view 1; sleep 9; done\nEOF'
blocks "a tab-stripped here-document fed to sh (#1901)" $'sh <<-EOF\n\tuntil gh pr merge 1; do sleep 9; done\nEOF'
blocks "a loop piped into bash (#1901)" "printf 'while true; do gh pr view 1; sleep 9; done' | bash"
blocks "a loop after a tab-indented <<- terminator (#1901)" $'cat > f <<-EOF\n\thi\n\tEOF\nwhile :; do gh pr view 1; done'
blocks "a loop inside an unterminated here-document (#1901)" $'cat > f <<EOF\nwhile :; do gh pr view 1; done'
blocks "a loop piped into /bin/bash (#1901)" "printf '%s' 'while :; do gh pr view 1; done' | /bin/bash"
blocks "a loop piped into /usr/bin/env bash (#1901)" "printf '%s' 'while :; do gh pr view 1; done' | /usr/bin/env bash"
blocks "a here-document fed to /bin/bash (#1901)" $'/bin/bash <<EOF\nwhile :; do gh pr view 1; done\nEOF'
blocks "a tight for loop over gh pr view (#1901)" 'for i in 1 2 3; do gh pr view 1; done'
blocks "a for loop inside bash -c (#1901)" "bash -c \"for i in 1 2 3; do gh pr checks 1; done\""
allows "sleep alone" 'sleep 5'
allows "an unrelated loop" 'for f in *.md; do wc -w "$f"; done'

# --- robustness: the hook must never break a turn ------------------------------
check "empty stdin exits 0" "echo '' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "malformed JSON exits 0" "echo 'not json' | bash \"$HOOK\"; [ \$? -eq 0 ]"
check "payload without a command exits 0" "echo '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\"C:\\\\\\\\x\\\\\\\\y.md\"}}' | bash \"$HOOK\"; [ \$? -eq 0 ]"

# --- Windows spellings get exactly the Unix verdict (#1891 install review) ------
# Every case above that runs bash or sh is replayed with each Windows spelling of
# that shell; the hook must give the same answer as for the plain name.
parity_bad=0; parity_n=0; parity_cases=0
# Token-aware replacement without regex replacement syntax, so backslashes survive.
swap() { # TEXT NAME FORM -> TEXT with each command token NAME (or /bin/NAME, /usr/bin/NAME) as FORM
  local s="$1" out="" re="(^|[^A-Za-z0-9_./-])(/usr/bin/|/bin/)?($2)([^A-Za-z0-9_.-]|\$)" m
  for ((;;)); do [[ $s =~ $re ]] || break
    m="${BASH_REMATCH[0]}"; out+="${s%%"$m"*}${BASH_REMATCH[1]}$3"; s="${BASH_REMATCH[4]}${s#*"$m"}"
  done
  printf '%s' "$out$s"
}
for c in "${CASES[@]}"; do
  hit=0; want=""
  for n in bash dash zsh ksh ash sh; do
    [[ $c =~ (^|[^A-Za-z0-9_./-])(/usr/bin/|/bin/)?$n([^A-Za-z0-9_.-]|$) ]] || continue
    [ -n "$want" ] || want="$(fire "$c")"; hit=1
    upper="$(printf '%s' "$n" | tr a-z A-Z)"
    for form in "$n.exe" "$upper.EXE" "\"C:/Program Files/Git/bin/$n.exe\"" "C:\\Git\\bin\\$n.exe"; do
      w="$(swap "$c" "$n" "$form")"
      [ "$w" != "$c" ] || { parity_bad=$((parity_bad+1)); printf '  parity replay did not change: %s\n' "$c"; continue; }
      parity_n=$((parity_n+1)); got="$(fire "$w")"
      [ "$got" = "$want" ] || { parity_bad=$((parity_bad+1)); printf '  parity mismatch (%s vs %s): %s\n' "$got" "$want" "$w"; }
    done
  done
  parity_cases=$((parity_cases+hit))
done
check "Windows shell spellings match the Unix verdict on every shell case ($parity_cases cases, $parity_n variants)" "[ $parity_cases -ge 12 ] && [ $parity_bad = 0 ]"
# A quoted Unix path is not a Windows spelling and keeps its old treatment.
allows "a here-document fed to a quoted Unix path keeps its old verdict" $'"/bin/bash" <<\'EOF\'\nwhile true; do gh pr view 1; sleep 9; done\nEOF'


# --- destructive-command guard (#2835) ------------------------------------------
# Real temp git repos: D is dirty, C is clean, "D S" has a space and is dirty.
G="$TMP/guard"; mkdir -p "$G"
mkrepo() { git init -q "$1" && git -C "$1" -c user.email=t@t -c user.name=t commit -q --allow-empty -m init \
  && printf 'x\n' >"$1/f" && git -C "$1" add f && git -C "$1" -c user.email=t@t -c user.name=t commit -q -m f; }
D="$G/dirty"; C="$G/clean"; DS="$G/dirty space"
mkrepo "$D"; mkrepo "$C"; mkrepo "$DS"; mkdir -p "$D/sub" "$G/norepo"
printf 'changed\n' >"$D/f"; printf 'changed\n' >"$DS/f"
# gfire <cwd> <command>: prints the exit status; stderr in $TMP/gerr.
gfire() { jq -nc --arg c "$2" --arg d "$1" '{tool_name:"Bash",cwd:$d,tool_input:{command:$c}}' | HOME="$G/home" bash "$HOOK" 2>"$TMP/gerr" >/dev/null; echo $?; }
grefuses() { local n="$1" d="$2"; shift 2; local c; for c in "$@"; do GC="$c" GD="$d"; check "guard refuses: $n [$c]" "[ \"\$(gfire \"\$GD\" \"\$GC\")\" = 2 ] && grep -q '^Blocked' \"$TMP/gerr\""; done; }
gallows() { local n="$1" d="$2"; shift 2; local c; for c in "$@"; do GC="$c" GD="$d"; check "guard allows: $n [$c]" "[ \"\$(gfire \"\$GD\" \"\$GC\")\" = 0 ]"; done; }
mkdir -p "$G/home"

grefuses "reset-hard dirty refused" "$D" 'git reset --hard' 'git reset --hard HEAD~1'
gallows "reset-hard clean allowed" "$C" 'git reset --hard'
grefuses "reset-hard quoted -C refused" "$C" "git -C \"$DS\" reset --hard"
grefuses "reset-hard chained cd refused" "$C" "cd \"$G\" && cd dirty && git reset --hard" "cd $D/sub && cd .. && git reset --hard"
gallows "reset-hard -C overrides cd" "$C" "cd \"$D\" && git -C \"$C\" reset --hard"
grefuses "reset-hard unknown dir refused" "$C" 'cd "$(pick)" && git reset --hard' 'cd "$SOMEWHERE" && git reset --hard'
grefuses "reset-hard status error refused" "$C" "git -C \"$G/norepo\" reset --hard"
grefuses "reset-hard in bash -c refused" "$D" "bash -c 'git reset --hard'" "sh -lc 'cd $D && git reset --hard'" "eval 'git reset --hard'"
grefuses "reset-hard windows spelling refused" "$D" 'GIT.EXE reset --hard' '"C:/Program Files/Git/bin/git.exe" reset --hard'
grefuses "reset-hard after a keyword or env prefix refused" "$D" 'if true; then git reset --hard; fi' 'GIT_TRACE=0 git reset --hard'
grefuses "reset-hard in a heredoc fed to bash refused" "$D" $'bash <<\'EOF\'\ngit reset --hard\nEOF'
gallows "operators in message allowed" "$D" 'git commit -m "a && b; rm -rf /"'
gallows "reset-hard in message allowed" "$D" 'git commit -m "undo git reset --hard"' "git commit -m 'git push --force'"
gallows "force in heredoc allowed" "$D" $'cat >notes.md <<\'EOF\'\ngit push --force origin main\nrm -rf ~\nEOF'
gallows "rm in echo allowed" "$D" 'echo "rm -rf ~"' "printf '%s' 'git clean -fdx'"
grefuses "restore worktree dirty refused" "$D" 'git restore .' 'git restore f' 'git checkout .' 'git checkout -- f' 'git checkout -f main'
grefuses "restore staged+worktree refused" "$D" 'git restore --staged --worktree .' 'git restore -SW .'
gallows "restore staged allowed" "$D" 'git restore --staged .' 'git restore -S f' 'git checkout main' 'git checkout -b feature'
grefuses "clean forced refused" "$C" 'git clean -fdx' 'git clean --force -d' 'git clean -df' 'git -C . clean -xf'
gallows "clean dry-run allowed" "$C" 'git clean -n' 'git clean -nd'
grefuses "push force refused" "$C" 'git push -f origin b' 'git push --force origin b' 'git push -uf origin b' 'git push --force=yes origin b'
grefuses "push plus refspec refused" "$C" 'git push origin +b' 'git push origin +HEAD:main'
gallows "push lease allowed" "$C" 'git push --force-with-lease origin b' 'git push --force-if-includes --force-with-lease origin b' 'git push origin b' 'git push -u origin HEAD'
grefuses "rm home/root spellings refused" "$C" 'rm -rf /' 'rm -fr ~' 'rm -r -f "$HOME"' 'rm -rf ${HOME}' 'rm -rf "$HOME/"' "rm -rf ''\"\$HOME\"" 'rm -Rf ~/' 'rm --recursive --force /' 'rm -rf -- ~'
gallows "rm single-quoted literal allowed" "$C" "rm -rf '\$HOME'"
gallows "rm quoted tilde allowed" "$C" 'rm -rf "~"'
grefuses "rm git dir refused" "$C" 'rm -rf .git' 'rm -rf repo/.git' 'rm -rf repo/.git/'
gallows "rm cleanup allowed" "$C" 'rm -rf "$TMPDIR/x"' 'rm -rf .claude/worktrees/old' 'rm -rf "$tmp"' 'rm -rf build dist' 'rm -r ~' 'rm -f ~/.cache/x' 'rm -rf node_modules/*'
grefuses "rm star refused" "$C" 'rm -rf *' 'rm -rf ./*' 'rm -rf ~/*' 'rm -rf /*'
grefuses "rm root normalized refused" "$C" 'rm -rf //' 'rm -rf /./' 'rm -rf .' 'rm -rf ..' 'rm -rf ../..'
gallows "guard parse error allowed" "$D" 'git reset --hard "unterminated'
gallows "ordinary git and rm commands allowed" "$D" 'git status' 'git log --oneline -3' 'git diff' 'rm -f f.tmp' 'git stash list'
check "a refusal names the safe alternative" "gfire \"$D\" 'git reset --hard' >/dev/null; grep -q 'WIP commit' \"$TMP/gerr\""
check "a force-push refusal names --force-with-lease" "gfire \"$C\" 'git push -f' >/dev/null; grep -q 'force-with-lease' \"$TMP/gerr\""
check "reset-hard on a dirty repo leaves the change in place" "grep -q changed \"$D/f\""

mkdir -p "$G/home/.config/ai-devops"; : >"$G/home/.config/ai-devops/destructive-guard.off"
gallows "off switch file disables the guard" "$D" 'git reset --hard' 'rm -rf ~'
rm -f "$G/home/.config/ai-devops/destructive-guard.off"
grefuses "removing the off switch turns the guard back on" "$D" 'git reset --hard'
# Fail-open: no python3 on PATH, or only a Windows Store alias.
GNOPY="$TMP/gnopy"; mkdir -p "$GNOPY"
for t in bash jq awk grep sed tr cat; do p="$(command -v "$t")" && ln -sf "$p" "$GNOPY/$t"; done
jq -nc --arg d "$D" '{tool_name:"Bash",cwd:$d,tool_input:{command:"git reset --hard"}}' | PATH="$GNOPY" "$GNOPY/bash" "$HOOK" >/dev/null 2>&1
check "guard python3 missing allowed" "[ \$? -eq 0 ]"
GWA="$TMP/gwa/WindowsApps"; mkdir -p "$GWA"; printf '#!/bin/sh\necho Blocked: alias ran\n' >"$GWA/python3"; chmod +x "$GWA/python3"
jq -nc --arg d "$D" '{tool_name:"Bash",cwd:$d,tool_input:{command:"git reset --hard"}}' | PATH="$GWA:$GNOPY" "$GNOPY/bash" "$HOOK" >/dev/null 2>&1
check "guard never runs a WindowsApps python3 alias" "[ \$? -eq 0 ]"
# Windows payload cwd: backslashes and a drive letter are normalized, not crashed on.
check "a Windows payload cwd does not crash the guard" "[ \"\$(gfire 'C:\\\\Users\\\\x\\\\repo' 'git status')\" = 0 ]"

# --- installer -----------------------------------------------------------------
CH="$TMP/claudehome"; mkdir -p "$CH"
printf '{"theme":"dark","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"echo pre-existing"}]}]}}\n' > "$CH/settings.json"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "installer registers the hook" "jq -e '[.hooks.PreToolUse[] | select(.matcher == \"Bash\") | .hooks[].command] | any(contains(\"pr-poll-guard-hook\"))' \"$CH/settings.json\""
check "installed command keeps the blocking exit status" "! grep -q 'pr-poll-guard-hook.*|| true' \"$CH/settings.json\""
check "installer keeps the pre-existing hook" "grep -q 'pre-existing' \"$CH/settings.json\""
check "installer keeps unrelated settings" "grep -q '\"theme\"' \"$CH/settings.json\""
check "installer leaves valid JSON" "jq -e 'type == \"object\"' \"$CH/settings.json\""
check "installer backs the file up" "[ -f \"$CH/settings.json.aidevops.bak\" ]"
check "installer copies the hook script" "[ -f \"$TMP/fakehome/.config/ai-devops/pr-poll-guard-hook\" ]"

before="$(md5sum < "$CH/settings.json")"
HOME="$TMP/fakehome" bash "$INSTALL" --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
after="$(md5sum < "$CH/settings.json")"
check "installer is idempotent" "[ \"$before\" = \"$after\" ]"
HOME="$TMP/fakehome" bash "$INSTALL" --check --claude-home "$CH" --repo-root "$ROOT" >/dev/null 2>&1
check "--check passes once installed" "[ \$? -eq 0 ]"

BAD="$TMP/badhome"; mkdir -p "$BAD"; printf '{ this is not json' > "$BAD/settings.json"
HOME="$TMP/fakehome2" bash "$INSTALL" --claude-home "$BAD" --repo-root "$ROOT" >/dev/null 2>&1; rc=$?
check "installer fails on unparseable settings" "[ $rc -ne 0 ]"
check "installer did not rewrite the broken file" "grep -q 'this is not json' \"$BAD/settings.json\""

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
