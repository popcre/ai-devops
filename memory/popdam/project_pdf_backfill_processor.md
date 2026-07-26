---
name: project_pdf_backfill_processor
description: "PDF/.ai full-library text-extraction backfill — who runs it (on-prem agent, not cloud), how it's triggered, and the bridge→Windows offload"
metadata: 
  node_type: memory
  type: project
  originSessionId: 06939cbd-c316-4172-a51e-f3146fc39d8f
---

The "PDF & .ai Text Extraction — Full Library Backfill" (Settings → admin) is **done by an on-prem agent, NOT the cloud**. The button only flips `admin_config.PDF_BACKFILL.status="running"`; an agent self-drives a claim loop (`claim-pdf-backfill-batch` → process → `complete-pdf-backfill-batch` → repeat) reading raw files from the NAS. Source `.ai`/`.pdf` live only on the NAS; the cloud (DO Spaces) holds only generated thumbnails + page PNGs, so anything reading raw bytes must run on-prem.

**Processor (as of 2026-06-10):** routed to the **Windows render agent** (`apps/windows-agent`, on the office LAN, mounts the share over SMB), with the **bridge agent** (`popdam-bridge` container on edgesynology2, mounts `/mnt/nas/mac`) as fallback. The whole mupdf→tesseract OCR→AI-vision cascade runs on the Windows VM to keep extraction CPU off the Synology. Routing gate in `agent-api` heartbeat (`trigger_pdf_backfill`): target = windows-render iff a healthy windows agent reports `version >= 0.16.0` (`metadata.version_info.version`), else bridge. This makes the cutover automatic + gap-free.

Key gotchas:
- **The claim loop self-drives** once started — it keeps claiming until `status != "running"` or remaining=0, independent of the heartbeat trigger. To stop an agent mid-run, set status=paused. To hand the job between agents cleanly: pause → wait for the new agent to be the routing target → resume (else both run concurrently; `claim_pdf_backfill_batch` is a non-locking SELECT, so concurrent claimers double-process the same rows — safe via `ON CONFLICT ignoreDuplicates` but wasteful).
- **`PDF_BACKFILL.total` is set once at trigger time.** A run started before a total-counting fix keeps its stale total; the complete handler marks `status="completed"` when `processed >= total`, so a too-low total stops the job early. Fix the live row's total if needed (`processed + count_pdf_backfill_remaining()`).
- The backfill processes both `.pdf` AND `.ai` (claim predicate = `file_type IN ('pdf','ai')` not in `pdf_text_samples`). `count_pdf_backfill_remaining()` is the source of truth (~53k in mid-2026).
- A heartbeat command only fires if the config key it checks is in that agent type's key set: `getConfigKeysForAgent()` in `agent-api` has separate `HEARTBEAT_CONFIG_KEYS_BRIDGE` vs `_WINDOWS` lists. `trigger_pdf_backfill` reads `configMap.PDF_BACKFILL`, so PDF_BACKFILL (and the AI keys for extraction) MUST be in the windows list or the command is silently always-false.
- Force a windows-agent self-update without waiting for its 10-min check: set `agent_registrations.metadata.trigger_update=true` (heartbeat delivers it, then clears). After a restart the agent reports `health.healthy=false` ("Preflight not yet run") for ~1 min until preflight maps the NAS — the routing gate requires `health.healthy=true`.
- Extracted "Files Used" sections populate `sku_files_used(sku, file_name)` via an INSERT trigger (`parse_pdf_files_used`) → shown in the group Details panel (`StyleGroupDetailPanel.tsx`, query key `["sku-files-used", group.sku]`).

A backfill fault must never crash the agent: `runPdfBackfill` catches claim/commit faults (logs + stops, next heartbeat re-triggers) and both agents have `process.on("unhandledRejection"/"uncaughtException")` nets. Before this (mid-2026) an uncaught claim error exit-1'd the bridge ~83× in a crash loop while still heartbeating, so it looked "online" but did nothing. Related: [[project_helper_storage_regions]] (edgesynology1 vs edgesynology2 roles).
