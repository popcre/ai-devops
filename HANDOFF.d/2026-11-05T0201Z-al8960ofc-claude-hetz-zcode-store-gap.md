---
issue: 2373
status: OPEN
owner: claude/hetz-zcode-handoff
---
# Hetz ZCode conversations never reach the transcript store

## 0. Business decisions only the owner can make
None — nothing in this workstream needs the owner. Already settled: Albert asked for a fix prompt on Nov 4, 2026.

## 1. What this application is
The transcript store is a daily searchable SQLite database of Albert's AI chat sessions, built on edge-dev3 from per-machine Dropbox folders (`ai/chat_transcripts/<machine>`). Plan: [plan_transcript-store.md](https://github.com/popcre/ai-devops/blob/main/plan_transcript-store.md). hetz is an Ubuntu server.

## 2. Goal
Make hetz ZCode conversations searchable and dated correctly in the store, like every other machine, and stop wasting Dropbox space. Triggered by Albert asking whether three unmatched hetz ZCode files were one-time.

## 3. Current state (measured Nov 4, 2026, 8:40 PM EST; counts only)
Nothing is changed on hetz. Other machines were fixed and merged in popcre/ai-devops PRs 2356, 2358, 2360, 2363, 2364.
- hetz database `.zcode/cli/db/db.sqlite` in the ai user's home: 54 sessions, all with messages. No `zcode-export` folder exists on hetz. Dropbox `hetz/zcode/sessions` does not hold exports.
- Dropbox `hetz/zcode`: dated folders 2026-10-29 through 2026-11-04 plus `rollout`; 24 objects, 1.171 GiB.
- The three unmatched files are `rollout/model-io-session_*.jsonl`.
- Not checked: querying the store itself for hetz ZCode rows; whether the three uploaded rollouts' sessions are still in the database.

## 4. What did not work
- First assumption that this was three stray files: wrong, they are a by-product.
- `ai-transcript-upload` is installed on hetz, but its timer is not (`not-found`), so its presence proves nothing.
- Matching rollouts by name: current rollout files are named `model-io-sess_*`, which the nightly filter `model-io-session_*` skips. All three current ones are in the database, so they lose nothing.

## 5. Root cause
hetz runs a hand-made cron, 3:17 AM daily, `bin/transcripts-to-dropbox.sh` in the ai user's home (not in the repo). It uses rclone to the remote `dropbox:ai/chat_transcripts/hetz`, copies the raw database into a new dated folder each night and copies matching rollouts. The store has no reader for raw databases or rollouts; only [zcode_export.py](https://github.com/popcre/ai-devops/blob/main/tools/transcript_store/zcode_export.py) output is readable, and [ai-transcript-upload](https://github.com/popcre/ai-devops/blob/main/bin/ai-transcript-upload) runs that only where it is installed. That uploader expects a local Dropbox folder; hetz has only rclone. It offers `--pull HOST`; whether any machine pulls hetz was not checked.

## 6. Exact next steps
1. Check `crontab -l` for transcript jobs on edge-dev3 and read the `--pull` section of the uploader. You'll know when you can say whether a pull of hetz exists.
2. Add to the hetz nightly job, before upload, the exporter into a local state folder, then rclone copy to `hetz/zcode/sessions`, preserving file times. Prefer a repo-owned script so it can self-update. You'll know it worked when the remote file count equals the exported count.
3. Stop the nightly database copy. You'll know when the next run adds no dated folder.
4. Wait for or trigger a store build. You'll know it worked when the store shows hetz ZCode sessions and its last-session date matches the database's newest message.
5. Confirm the three rollouts' sessions are in the store; if any are not, recover from the newest database copy.
6. Only then delete old database copies, keeping the newest, after confirming Dropbox retains them recoverably. You'll know when the folder is near its export size.
7. Record the proof on issue 2373, close it and delete this file.

## 7. Constraints
Never paste transcript content into GitHub; counts only. Reasoning and tool output stay out of exports. Do not edit servers without the script being in GitHub. Use class `infrastructure` with `ai-task-gates`. `$AI_GH_SIGNATURE` was empty; sign manually with chat id and machine. Use a worktree; never push to main.

## 8. Access
SSH to hetz needs the 916-alien key, users ai or root. rclone is in the ai user's `bin`. Secrets stay in 1Password `vibe_coding`. The root account has a `.zcode` folder with no database.

## 9. Risks
Raw copies contain unfiltered conversations; deleting too early loses recovery. The live database is in use; open it read-only. Decision Nov 4, 2026: fix hetz at the source rather than teach the store to read raw databases, since the exporter filters private reasoning.

## Self-audit
1. Newcomer can continue: yes, sections 1, 3, 5, 6. 2. As well as me: yes, sections 4, 5, 9. 3. All details: yes, with unchecked items named in 3. 4. Owner decisions: swept, none, section 0.
