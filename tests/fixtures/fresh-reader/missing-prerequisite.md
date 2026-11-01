# Synthetic task: build the catalog digest

## Goal

Create `digest.txt` containing the SHA-256 digest of `catalog.txt`.

## Scope

Read `catalog.txt` and write `digest.txt` in the task workspace only. Do not
access network services or files outside the task workspace.

## Prerequisites

- `catalog.txt` is supplied beside this plan.
- The task workspace is writable.

## Steps

1. Run `sha256sum catalog.txt`.
2. Copy the digest (the first field) to `digest.txt`, followed by one newline.

## Check

Run `sha256sum catalog.txt` again and confirm its first field matches the
contents of `digest.txt`.

## Recovery

If the command fails, leave `digest.txt` unchanged and report the error to the
task owner.
