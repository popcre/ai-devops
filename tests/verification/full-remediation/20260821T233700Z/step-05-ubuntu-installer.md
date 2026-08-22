# Step 5 verification - Ubuntu installer source behavior

- Every install action is classified as required, optional, or skipped and is
  included in the final summary.
- Every required-stage fixture returns nonzero while still reaching the summary.
- Optional provider failure is named but does not make the install nonzero.
- Node, npm, and npx are detected and verified independently.
- `update.sh` reports the exact source SHA it attempted to install.
- Live Ubuntu restore remains an explicit Step 16 rollout gate; the Step 7
  config migrator must also be connected before this step is complete.
