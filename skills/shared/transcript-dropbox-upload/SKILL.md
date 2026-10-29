---
name: transcript-dropbox-upload
description: One-way delta backup of the private ai-devops-transcripts archive to Albert's Dropbox folder. Use when the user says "upload the transcripts to Dropbox", "back up transcripts to Dropbox", "sync transcripts to Dropbox", "upload new transcripts", "what transcripts still need uploading to Dropbox", or asks whether the Dropbox transcript backup is complete. Refreshes the archive, copies only what Dropbox is missing or older, decompresses the repo's .jsonl.xz collections on the way, verifies the result, and reports counts and relative paths only — never opens, quotes, searches, or transmits transcript content.
---

# transcript-dropbox-upload

Back up the transcript archive to Dropbox and prove it complete. Source of
truth: the private `ai-devops-transcripts` GitHub repo checked out locally
(Windows boxes: `D:\repos\ai-devops-transcripts`). Destination:
`C:\Users\ahazan\Dropbox\ai\chat_transcripts`. The job is a one-way delta
copy (repo → Dropbox): find exactly what the destination lacks or has older,
copy only that, re-verify, and report.

## Safety (do first, always)

- The archive is **private evidence**. Inside the archive repo run
  `ai-task-gates start --class private-evidence` before anything else. Never
  open, quote, summarize, grep, or paste raw `.jsonl` content; the final
  report carries file counts and relative paths only.
- The destination is Albert's private Dropbox folder — a sanctioned backup
  target, not a third party. Never copy archive content anywhere else. Never
  delete, move, mirror-prune, or "tidy" anything already in the destination.
- The archive checkout is landing-only: `git fetch` and fast-forward pull
  only. Never commit, push, or rewrite there. Compare against `origin/main`
  and pull first if behind.
- Everything is compared and copied by path — file contents are never read
  (except the byte-stream pass-through of the copy itself).

## Layout mapping (settled 2026-10-29; do not rediscover)

| Repo path | Dropbox path | Comparison |
|---|---|---|
| `claude_chats/<machine>/<rest>` | `<machine>/claude/<rest>` | path + size |
| `codex_chats/<machine>/<rest>` | `<machine>/codex/<rest>` | path + size |
| `collection-*/claude_chats/<machine>/<rest>` | `<machine>/claude/<rest>` | name-only |
| `collection-*/codex_chats/<machine>/<rest>` | `<machine>/codex/<rest>` | name-only |

Conventions that decided past uploads:

- The destination stores everything **uncompressed** (zero `.jsonl.xz` files
  there). Repo collections are stored `.xz`; decompress on copy with
  `xz -dkc SRC.xz > DEST` so Dropbox keeps the plain `.jsonl`.
- `edge-dev/_upload-log-YYYY-MM-DD.txt` files record past direct-from-machine
  uploads and are the authority for "last time we uploaded". Read the newest
  one before trusting a small gap.
- `edge-dev3/` is a separate WSL-side source that does not exist in the repo.
  Before copying an `edge-dev/...` target, check whether the same relative
  path already exists under `edge-dev3/`; if it does, the file is already
  backed up — skip it and say so. Never rewrite `edge-dev3/` from repo data.
- Machine folders that exist only in Dropbox (`al8960ofc`, `compshop`,
  `seafile`, `edge-dev/grok|kimi|mimo|qwen|zcode`, `_audit`) came from those
  machines directly. Out of scope; never touched, never deleted.
- Skip non-transcripts: collection-level `README.md`, `unpack.sh`,
  `.gitignore`. (`session_index.jsonl` is a transcript-side file and copies.)
- **Never compare mtimes** — git checkout resets them. Machine trees: copy
  when missing or when repo size > destination size; a larger destination
  file is newer (uploaded later from the machine) — leave it and note it.
  Collections: compressed sizes are incomparable, so copy on missing name.

## Procedure

Work in Git Bash. Set `repo=` to the archive checkout and
`dbx=/c/Users/ahazan/Dropbox/ai/chat_transcripts`.

1. Refresh the source and confirm it matches the remote:
   ```bash
   git -C "$repo" fetch origin
   git -C "$repo" rev-parse HEAD origin/main   # must be equal; else: git -C "$repo" pull --ff-only
   ```
2. Build the repo→destination manifest (maps every repo transcript to its
   Dropbox path; collections dedupe to their newest version by `sort -u`):
   ```bash
   : > /tmp/repo-map.txt
   for tool_dir in claude_chats codex_chats; do
     tool=${tool_dir%_chats}
     for src in "$repo/$tool_dir"/*/; do
       [ -d "$src" ] || continue
       find "$src" -type f -printf '%s\t'"$(basename "$src")/$tool"'/%P\n' >> /tmp/repo-map.txt
     done
   done
   for c in "$repo"/collection-*/; do
     [ -d "$c" ] || continue
     ( cd "$c" && git ls-files | while IFS= read -r f; do
         case "$f" in
           claude_chats/*) t=claude ;; codex_chats/*) t=codex ;;
           *) continue ;;
         esac
         inner=${f#*_chats/}; m=${inner%%/*}; rest=${inner#*/}
         printf '%s\t%s\n' '-' "$m/$t/${rest%.xz}"
       done ) >> /tmp/repo-map.txt
   done
   sort -u -o /tmp/repo-map.txt /tmp/repo-map.txt
   ```
3. Manifest the destination and classify the delta:
   ```bash
   find "$dbx" -type f -printf '%s\t%P\n' > /tmp/dropbox-manifest.txt
   awk -F'\t' 'NR==FNR{d[$2]=$1;next}
     !($2 in d){print "MISSING\t"$2}
     ($2 in d && $1!="-" && d[$2]<$1){print "REPO-LARGER\t"$2}' \
     /tmp/dropbox-manifest.txt /tmp/repo-map.txt > /tmp/delta.txt
   ```
   Expected steady state: both counts zero. `REPO-LARGER` over machine trees
   is a genuine newer-in-repo session; copy it (step 4 overwrites).
4. Copy the delta. Machine-tree files copy plain; collection files resolve
   newest-collection-first and decompress `.xz`. Files already present under
   `edge-dev3/` are skipped as already backed up:
   ```bash
   mapfile -t cols < <(ls -1d "$repo"/collection-* 2>/dev/null | sort -r)
   copied=0; nosrc=0
   while IFS= read -r line; do
     t=${line#*$'\t'}; t=${t%%$'\t'*}
     case "$t" in */README.md|*/unpack.sh|*/.gitignore) continue ;; esac
     case "$t" in edge-dev/*)
       [ -f "$dbx/edge-dev3/${t#edge-dev/}" ] && { echo "SKIP already in edge-dev3: $t"; continue ;; }
     esac
     m=${t%%/*}; rem=${t#*/}; tool=${rem%%/*}; rest=${rem#*/}
     src="$repo/${tool}_chats/$m/$rest"; [ -f "$src" ] || src=""
     if [ -z "$src" ]; then
       for c in "${cols[@]}"; do
         for cand in "$c/${tool}_chats/$m/$rest.xz" "$c/${tool}_chats/$m/$rest"; do
           [ -f "$cand" ] && { src="$cand"; break; }
         done
         [ -n "$src" ] && break
       done
     fi
     if [ -z "$src" ]; then echo "NOSRC $t"; nosrc=$((nosrc+1)); continue; fi
     mkdir -p "$(dirname "$dbx/$t")" || { echo "MKDIRFAIL $t"; continue; }
     case "$src" in *.xz) xz -dkc "$src" > "$dbx/$t" ;; *) cp "$src" "$dbx/$t" ;; esac \
       && copied=$((copied+1)) || echo "COPYFAIL $t"
   done < <(grep -E '^(MISSING|REPO-LARGER)' /tmp/delta.txt | cut -f2-)
   echo "copied=$copied nosrc=$nosrc"
   ```
5. Verify by re-running steps 3's two commands into fresh files and the same
   `awk` join. The only remaining `MISSING` lines must be the skipped
   support files. The backup is complete only when that holds.

## Report

Close with: archive commit verified (or pulled), files copied, files skipped
as already-in-`edge-dev3` or destination-newer, `NOSRC` gaps with paths, and
the verification result ("every transcript in the archive now has a copy in
Dropbox" only after step 5 proves it). Counts and relative paths only — no
content, no samples.
