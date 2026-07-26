# hiclaw Project Memory Index

This index tracks memory files for the hiclaw project. Each entry links to a file with detailed context.

## Incidents & Fixes

- [MinIO recursion fix (2026-05-20)](project_minio_recursion_fix.md) — k8s startup mc mirror pull creates recursive storage loop; fix is --exclude guards in start-manager-agent.sh
- [Gateway restart loop fix (2026-05-21)](project_restart_loop_fix.md) — keeper writing commands:{} caused 5-min restart loop; fix is commands:{restart:true} to match startup baseline
