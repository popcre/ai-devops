# Complete synthetic task: count the sample rows

## Goal

Create `result.txt` containing the number `3`, because the supplied sample has
three rows.

## Scope

Read this plan and the supplied `sample.csv`. Create or replace `result.txt` in
the task workspace. Do not access network services or files outside the task
workspace.

## Prerequisites

- Python 3 is available.
- The task workspace is writable.
- `sample.csv` is supplied beside this plan with exactly three data rows and a
  header row.

## Steps

1. Run `python3 -c "import csv; print(sum(1 for _ in csv.DictReader(open('sample.csv', newline=''))))"`.
2. Write the printed count and a newline to `result.txt`.

## Check

Confirm `result.txt` contains exactly `3` followed by one newline.

## Recovery

If the command fails, leave `result.txt` unchanged, report the error, and ask
the task owner to restore the sample file or Python access before retrying.
