---
name: feedback-dont-repeat-acknowledged-items
description: "Don't keep re-listing an open/side item the user has already acknowledged or declined"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e23aede2-147b-471e-9312-421d1d570c51
---

Once the user has acknowledged a flagged side item (or told me to drop it), stop repeating it in subsequent summaries.

**Why:** In this session I kept re-listing "rotate the 1Password service-account token" in every wrap-up; the user found it noise and told me to stop bringing it up.

**How to apply:** Flag an out-of-band item once. If the user acknowledges, declines, or says to drop it, don't resurface it in later status summaries unless they ask or it becomes newly relevant.
