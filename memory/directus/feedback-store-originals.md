---
name: feedback-store-originals
description: "User wants original assets preserved — don't impose resizing/optimization on stored images without asking"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 4809c66c-6d94-400a-b923-0c3bf58ec44c
---

When migrating/storing product images, the user wants the **original files kept as-is, regardless of size or format**. On 2026-06-12 I added a sharp→webp ≤1000px downscale to the DigitalOcean Spaces uploader for board performance; the user said "don't resize images" and I reverted it to store originals verbatim.

**Why:** these are product/brand assets with downstream uses (DAM, print, full-quality review) where resolution matters; board-card display speed is a separate, lower concern that can be solved later with a CDN/thumbnail layer over the untouched originals.

**How to apply:** default to storing originals. If a size/perf tradeoff seems worth it, ask first rather than silently optimizing. See [[product-image-storage]].
