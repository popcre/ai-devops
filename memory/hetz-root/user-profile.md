---
name: user-profile
description: "Who the user is — a vibe-coder running enterprise apps on one server, not a sysadmin"
metadata: 
  node_type: memory
  type: user
  originSessionId: 37bab05e-83be-4d09-bfd4-76fb768b2d2f
---

The user (u2giants@gmail.com) is a self-described "vibe-coder," NOT a sysadmin or devops
engineer. They run multiple enterprise applications on a single Hetzner Ubuntu 24.04 VPS
(178.156.180.212 / designflow.app), all deployed via Coolify. They drive infrastructure work
through AI (Claude Code, Codex) rather than hand-managing it, and want changes authored +
maintained by AI with themselves as the approver/operator.

Implications for how to help:
- Explain concepts, don't just emit commands. Favor readable, well-documented tooling
  (Ansible, Docker) over expert-only systems (NixOS) — partly because AI tooling is more
  reliable on the mainstream stack.
- They care deeply about disaster recovery / rebuildability and worry about single points of
  failure. See [[infra-as-code-initiative]].
- Prefer GitHub Actions (CI runner) as the serialization/apply point for infra changes over
  running tooling on the box itself.
