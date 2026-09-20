# Workflow efficiency baseline — September 20, 2026

For implementation use the [current plan STATUS](../../../plan_workflow-efficiency.md).
This is a public, read-only audit snapshot, not installed acceptance evidence.

## Source and method

Source/main verified: `fbd567256ac9f173893fb1ebd3cd6da52b26b310`.
Sample: latest 100 runs from the repository Actions `verify.yml` workflow at
audit time. Original reads used `bin/ai-gh api
repos/u2giants/ai-devops/actions/workflows/verify.yml/runs?per_page=100`.
The table below freezes that sample; repeating the endpoint later produces a
different sample. Run IDs link to the original public records.

Elapsed time means `updated_at - created_at`, including retries/idle gaps, not
CPU time or one attempt's duration. Only successful runs contribute to success
percentiles. The reported p90 uses nearest rank; median for the initial rounded
summary used the upper middle item (45 PR successes, 20 merge-group successes).
The distinction does not change the rounded seven-minute merge-queue conclusion.
Incomplete runs are counted separately. Job-attempt records can reuse earlier
successful jobs: do not count them as repeated execution without timestamp proof.

66 successes, 20 cancellations, 12 failures and two incomplete. Successful PR
elapsed median approximately 35 minutes/p90 58; successful merge-group median
approximately seven/p90 15. This sample does not establish the cause of every
failure/cancellation or locate Albert's particular reported 12-hour event.

## Decisive examples and existing repairs

- [Run 35479598344](https://github.com/popcre/ai-devops/actions/runs/35479598344):
  about 101 minutes across two attempts. Initial Windows section 4 failed at
  approximately 30 minutes; its retry passed in approximately 35. Linux sections
  were about five minutes; hosted reviewer lane 37 minutes. Other successful
  job timestamps were carried into the retry, not proof of full physical reruns.
- [Issue #633](https://github.com/popcre/ai-devops/issues/633), OPEN at audit:
  historical September 18 30,384-file incident reports five-plus hours per
  inventory pass. `bin/ai-gemini:105–131` confirms per-file process startup.
  No multi-hour benchmark was run by the planner.
- [Issue #637](https://github.com/popcre/ai-devops/issues/637), OPEN: distinct
  first-probe/resolve deadline and failure-label residuals; coordinate wrapper edits.
- [PR #639](https://github.com/popcre/ai-devops/pull/639), merge `918866b8`:
  forward-target tolerance and slow-evidence warning already landed. #622 remains
  open but its entire older description is not current unfinished work.
- Live ruleset `21564317`: required context `verification-closure`, GitHub
  required review count 0, merge queue check response timeout 120 minutes.
  Independent reviewer-safety review remains a separate repository requirement.

## Frozen run sample

Generated from the saved public API response. Empty conclusions are shown as
`incomplete`; elapsed values for them are observation age, not completion time.

| Run | Event | Outcome | Attempt | Created UTC | Updated UTC | Elapsed minutes |
|---|---|---|---:|---|---|---:|
| [35518482177](https://github.com/popcre/ai-devops/actions/runs/35518482177) | pull_request | incomplete | 1 | 2026-09-20T15:05:24Z | 2026-09-20T15:09:16Z | 3.87 |
| [35518374522](https://github.com/popcre/ai-devops/actions/runs/35518374522) | pull_request | incomplete | 1 | 2026-09-20T15:03:26Z | 2026-09-20T15:09:51Z | 6.42 |
| [35517867353](https://github.com/popcre/ai-devops/actions/runs/35517867353) | pull_request | success | 1 | 2026-09-20T14:53:30Z | 2026-09-20T14:54:04Z | 0.57 |
| [35517739654](https://github.com/popcre/ai-devops/actions/runs/35517739654) | pull_request | success | 1 | 2026-09-20T14:50:54Z | 2026-09-20T14:51:27Z | 0.55 |
| [35517714958](https://github.com/popcre/ai-devops/actions/runs/35517714958) | pull_request | cancelled | 1 | 2026-09-20T14:50:28Z | 2026-09-20T14:50:57Z | 0.48 |
| [35517480048](https://github.com/popcre/ai-devops/actions/runs/35517480048) | pull_request | success | 1 | 2026-09-20T14:45:53Z | 2026-09-20T14:46:27Z | 0.57 |
| [35516828472](https://github.com/popcre/ai-devops/actions/runs/35516828472) | merge_group | success | 1 | 2026-09-20T14:33:05Z | 2026-09-20T14:39:58Z | 6.88 |
| [35515371169](https://github.com/popcre/ai-devops/actions/runs/35515371169) | pull_request | success | 1 | 2026-09-20T14:04:29Z | 2026-09-20T14:04:59Z | 0.50 |
| [35514513931](https://github.com/popcre/ai-devops/actions/runs/35514513931) | pull_request | success | 1 | 2026-09-20T13:47:08Z | 2026-09-20T14:32:42Z | 45.57 |
| [35486899121](https://github.com/popcre/ai-devops/actions/runs/35486899121) | merge_group | success | 1 | 2026-09-20T03:33:50Z | 2026-09-20T03:40:17Z | 6.45 |
| [35486847596](https://github.com/popcre/ai-devops/actions/runs/35486847596) | pull_request | success | 1 | 2026-09-20T03:32:38Z | 2026-09-20T03:33:17Z | 0.65 |
| [35486153415](https://github.com/popcre/ai-devops/actions/runs/35486153415) | merge_group | success | 1 | 2026-09-20T03:16:36Z | 2026-09-20T03:22:56Z | 6.33 |
| [35484065857](https://github.com/popcre/ai-devops/actions/runs/35484065857) | merge_group | success | 1 | 2026-09-20T02:28:12Z | 2026-09-20T02:34:39Z | 6.45 |
| [35483347349](https://github.com/popcre/ai-devops/actions/runs/35483347349) | pull_request | success | 1 | 2026-09-20T02:11:45Z | 2026-09-20T02:52:08Z | 40.38 |
| [35481368192](https://github.com/popcre/ai-devops/actions/runs/35481368192) | pull_request | failure | 1 | 2026-09-20T01:25:54Z | 2026-09-20T02:10:41Z | 44.78 |
| [35479598344](https://github.com/popcre/ai-devops/actions/runs/35479598344) | pull_request | success | 2 | 2026-09-20T00:45:21Z | 2026-09-20T02:26:10Z | 100.82 |
| [35476821417](https://github.com/popcre/ai-devops/actions/runs/35476821417) | pull_request | success | 1 | 2026-09-19T23:41:54Z | 2026-09-19T23:42:27Z | 0.55 |
| [35421800654](https://github.com/popcre/ai-devops/actions/runs/35421800654) | merge_group | success | 1 | 2026-09-19T04:37:44Z | 2026-09-19T04:43:58Z | 6.23 |
| [35419619268](https://github.com/popcre/ai-devops/actions/runs/35419619268) | pull_request | success | 1 | 2026-09-19T03:49:02Z | 2026-09-19T04:34:36Z | 45.57 |
| [35417763658](https://github.com/popcre/ai-devops/actions/runs/35417763658) | pull_request | cancelled | 1 | 2026-09-19T03:09:47Z | 2026-09-19T03:49:15Z | 39.47 |
| [35416860863](https://github.com/popcre/ai-devops/actions/runs/35416860863) | pull_request | cancelled | 1 | 2026-09-19T02:50:50Z | 2026-09-19T03:10:01Z | 19.18 |
| [35416446946](https://github.com/popcre/ai-devops/actions/runs/35416446946) | pull_request | cancelled | 1 | 2026-09-19T02:42:25Z | 2026-09-19T02:51:04Z | 8.65 |
| [35415708378](https://github.com/popcre/ai-devops/actions/runs/35415708378) | pull_request | cancelled | 1 | 2026-09-19T02:27:37Z | 2026-09-19T02:42:57Z | 15.33 |
| [35415500386](https://github.com/popcre/ai-devops/actions/runs/35415500386) | pull_request | cancelled | 1 | 2026-09-19T02:23:23Z | 2026-09-19T02:27:54Z | 4.52 |
| [35414449732](https://github.com/popcre/ai-devops/actions/runs/35414449732) | pull_request | cancelled | 1 | 2026-09-19T02:01:50Z | 2026-09-19T02:23:37Z | 21.78 |
| [35414410624](https://github.com/popcre/ai-devops/actions/runs/35414410624) | merge_group | success | 1 | 2026-09-19T02:01:01Z | 2026-09-19T02:07:56Z | 6.92 |
| [35414113562](https://github.com/popcre/ai-devops/actions/runs/35414113562) | merge_group | success | 1 | 2026-09-19T01:55:05Z | 2026-09-19T02:02:53Z | 7.80 |
| [35413062082](https://github.com/popcre/ai-devops/actions/runs/35413062082) | pull_request | cancelled | 1 | 2026-09-19T01:34:16Z | 2026-09-19T02:02:04Z | 27.80 |
| [35412171436](https://github.com/popcre/ai-devops/actions/runs/35412171436) | pull_request | cancelled | 1 | 2026-09-19T01:17:06Z | 2026-09-19T01:34:32Z | 17.43 |
| [35411988916](https://github.com/popcre/ai-devops/actions/runs/35411988916) | pull_request | success | 1 | 2026-09-19T01:13:48Z | 2026-09-19T02:00:36Z | 46.80 |
| [35411122847](https://github.com/popcre/ai-devops/actions/runs/35411122847) | pull_request | cancelled | 1 | 2026-09-19T00:58:12Z | 2026-09-19T01:17:20Z | 19.13 |
| [35410477217](https://github.com/popcre/ai-devops/actions/runs/35410477217) | merge_group | success | 1 | 2026-09-19T00:46:17Z | 2026-09-19T00:54:12Z | 7.92 |
| [35409942279](https://github.com/popcre/ai-devops/actions/runs/35409942279) | pull_request | success | 1 | 2026-09-19T00:36:43Z | 2026-09-19T01:13:55Z | 37.20 |
| [35409873568](https://github.com/popcre/ai-devops/actions/runs/35409873568) | pull_request | cancelled | 1 | 2026-09-19T00:35:29Z | 2026-09-19T01:14:02Z | 38.55 |
| [35409840194](https://github.com/popcre/ai-devops/actions/runs/35409840194) | pull_request | cancelled | 1 | 2026-09-19T00:34:54Z | 2026-09-19T00:36:49Z | 1.92 |
| [35409766779](https://github.com/popcre/ai-devops/actions/runs/35409766779) | pull_request | cancelled | 1 | 2026-09-19T00:33:35Z | 2026-09-19T00:58:31Z | 24.93 |
| [35408457128](https://github.com/popcre/ai-devops/actions/runs/35408457128) | pull_request | cancelled | 1 | 2026-09-19T00:10:53Z | 2026-09-19T00:34:06Z | 23.22 |
| [35407862499](https://github.com/popcre/ai-devops/actions/runs/35407862499) | pull_request | success | 1 | 2026-09-19T00:01:10Z | 2026-09-19T00:01:46Z | 0.60 |
| [35407781923](https://github.com/popcre/ai-devops/actions/runs/35407781923) | pull_request | success | 1 | 2026-09-19T00:00:02Z | 2026-09-19T00:00:47Z | 0.75 |
| [35407771813](https://github.com/popcre/ai-devops/actions/runs/35407771813) | pull_request | failure | 1 | 2026-09-18T23:59:52Z | 2026-09-19T00:35:04Z | 35.20 |
| [35407240936](https://github.com/popcre/ai-devops/actions/runs/35407240936) | merge_group | success | 1 | 2026-09-18T23:50:51Z | 2026-09-18T23:57:16Z | 6.42 |
| [35406753282](https://github.com/popcre/ai-devops/actions/runs/35406753282) | pull_request | success | 1 | 2026-09-18T23:42:46Z | 2026-09-19T00:31:28Z | 48.70 |
| [35406664552](https://github.com/popcre/ai-devops/actions/runs/35406664552) | pull_request | cancelled | 1 | 2026-09-18T23:41:20Z | 2026-09-18T23:44:06Z | 2.77 |
| [35406448295](https://github.com/popcre/ai-devops/actions/runs/35406448295) | merge_group | success | 1 | 2026-09-18T23:37:52Z | 2026-09-18T23:45:33Z | 7.68 |
| [35405244143](https://github.com/popcre/ai-devops/actions/runs/35405244143) | pull_request | success | 1 | 2026-09-18T23:19:40Z | 2026-09-18T23:50:29Z | 30.82 |
| [35404573272](https://github.com/popcre/ai-devops/actions/runs/35404573272) | pull_request | failure | 1 | 2026-09-18T23:09:35Z | 2026-09-19T00:01:48Z | 52.22 |
| [35403577508](https://github.com/popcre/ai-devops/actions/runs/35403577508) | pull_request | cancelled | 1 | 2026-09-18T22:54:51Z | 2026-09-18T23:20:46Z | 25.92 |
| [35403369492](https://github.com/popcre/ai-devops/actions/runs/35403369492) | pull_request | success | 1 | 2026-09-18T22:51:49Z | 2026-09-18T23:38:26Z | 46.62 |
| [35403225772](https://github.com/popcre/ai-devops/actions/runs/35403225772) | pull_request | success | 1 | 2026-09-18T22:49:46Z | 2026-09-18T23:37:29Z | 47.72 |
| [35402600135](https://github.com/popcre/ai-devops/actions/runs/35402600135) | merge_group | success | 1 | 2026-09-18T22:40:41Z | 2026-09-18T22:47:11Z | 6.50 |
| [35402208162](https://github.com/popcre/ai-devops/actions/runs/35402208162) | pull_request | success | 1 | 2026-09-18T22:35:18Z | 2026-09-18T22:35:56Z | 0.63 |
| [35401321644](https://github.com/popcre/ai-devops/actions/runs/35401321644) | merge_group | success | 1 | 2026-09-18T22:23:21Z | 2026-09-18T22:29:28Z | 6.12 |
| [35399596460](https://github.com/popcre/ai-devops/actions/runs/35399596460) | merge_group | failure | 1 | 2026-09-18T22:01:05Z | 2026-09-18T22:07:27Z | 6.37 |
| [35398700847](https://github.com/popcre/ai-devops/actions/runs/35398700847) | pull_request | success | 1 | 2026-09-18T21:49:50Z | 2026-09-18T22:36:27Z | 46.62 |
| [35397991570](https://github.com/popcre/ai-devops/actions/runs/35397991570) | merge_group | success | 1 | 2026-09-18T21:41:02Z | 2026-09-18T21:47:18Z | 6.27 |
| [35396798615](https://github.com/popcre/ai-devops/actions/runs/35396798615) | merge_group | success | 1 | 2026-09-18T21:26:43Z | 2026-09-18T21:33:04Z | 6.35 |
| [35395583321](https://github.com/popcre/ai-devops/actions/runs/35395583321) | pull_request | success | 1 | 2026-09-18T21:12:42Z | 2026-09-18T22:00:29Z | 47.78 |
| [35395539517](https://github.com/popcre/ai-devops/actions/runs/35395539517) | pull_request | success | 1 | 2026-09-18T21:12:12Z | 2026-09-18T21:13:22Z | 1.17 |
| [35393771006](https://github.com/popcre/ai-devops/actions/runs/35393771006) | pull_request | success | 1 | 2026-09-18T20:52:12Z | 2026-09-18T21:27:33Z | 35.35 |
| [35393508020](https://github.com/popcre/ai-devops/actions/runs/35393508020) | pull_request | success | 1 | 2026-09-18T20:49:15Z | 2026-09-18T20:49:53Z | 0.63 |
| [35391386368](https://github.com/popcre/ai-devops/actions/runs/35391386368) | merge_group | success | 1 | 2026-09-18T20:25:37Z | 2026-09-18T20:39:29Z | 13.87 |
| [35391073859](https://github.com/popcre/ai-devops/actions/runs/35391073859) | pull_request | success | 1 | 2026-09-18T20:22:16Z | 2026-09-18T21:16:33Z | 54.28 |
| [35388782455](https://github.com/popcre/ai-devops/actions/runs/35388782455) | workflow_dispatch | success | 1 | 2026-09-18T19:57:16Z | 2026-09-18T21:43:52Z | 106.60 |
| [35388512188](https://github.com/popcre/ai-devops/actions/runs/35388512188) | pull_request | success | 1 | 2026-09-18T19:54:16Z | 2026-09-18T20:45:53Z | 51.62 |
| [35388163388](https://github.com/popcre/ai-devops/actions/runs/35388163388) | merge_group | success | 1 | 2026-09-18T19:50:25Z | 2026-09-18T20:37:02Z | 46.62 |
| [35387874779](https://github.com/popcre/ai-devops/actions/runs/35387874779) | pull_request | success | 1 | 2026-09-18T19:47:16Z | 2026-09-18T20:59:44Z | 72.47 |
| [35387557184](https://github.com/popcre/ai-devops/actions/runs/35387557184) | pull_request | success | 1 | 2026-09-18T19:43:49Z | 2026-09-18T20:27:44Z | 43.92 |
| [35387245586](https://github.com/popcre/ai-devops/actions/runs/35387245586) | pull_request | success | 1 | 2026-09-18T19:40:24Z | 2026-09-18T20:37:55Z | 57.52 |
| [35387237206](https://github.com/popcre/ai-devops/actions/runs/35387237206) | pull_request | success | 1 | 2026-09-18T19:40:19Z | 2026-09-18T20:25:19Z | 45.00 |
| [35386293625](https://github.com/popcre/ai-devops/actions/runs/35386293625) | workflow_dispatch | failure | 1 | 2026-09-18T19:30:15Z | 2026-09-18T21:30:25Z | 120.17 |
| [35384385262](https://github.com/popcre/ai-devops/actions/runs/35384385262) | merge_group | success | 1 | 2026-09-18T19:09:57Z | 2026-09-18T19:16:11Z | 6.23 |
| [35383567973](https://github.com/popcre/ai-devops/actions/runs/35383567973) | merge_group | success | 1 | 2026-09-18T19:01:27Z | 2026-09-18T19:10:16Z | 8.82 |
| [35383556010](https://github.com/popcre/ai-devops/actions/runs/35383556010) | pull_request | failure | 1 | 2026-09-18T19:01:19Z | 2026-09-18T19:35:48Z | 34.48 |
| [35381229026](https://github.com/popcre/ai-devops/actions/runs/35381229026) | pull_request | success | 1 | 2026-09-18T18:37:07Z | 2026-09-18T19:37:58Z | 60.85 |
| [35380867972](https://github.com/popcre/ai-devops/actions/runs/35380867972) | workflow_dispatch | failure | 1 | 2026-09-18T18:33:26Z | 2026-09-18T20:20:06Z | 106.67 |
| [35380817799](https://github.com/popcre/ai-devops/actions/runs/35380817799) | pull_request | success | 1 | 2026-09-18T18:32:54Z | 2026-09-18T19:10:23Z | 37.48 |
| [35379852725](https://github.com/popcre/ai-devops/actions/runs/35379852725) | merge_group | success | 1 | 2026-09-18T18:23:01Z | 2026-09-18T18:44:59Z | 21.97 |
| [35379834723](https://github.com/popcre/ai-devops/actions/runs/35379834723) | pull_request | success | 1 | 2026-09-18T18:22:50Z | 2026-09-18T18:34:16Z | 11.43 |
| [35379640759](https://github.com/popcre/ai-devops/actions/runs/35379640759) | workflow_dispatch | cancelled | 1 | 2026-09-18T18:20:49Z | 2026-09-18T18:33:55Z | 13.10 |
| [35378626150](https://github.com/popcre/ai-devops/actions/runs/35378626150) | pull_request | success | 1 | 2026-09-18T18:10:32Z | 2026-09-18T19:09:36Z | 59.07 |
| [35378581829](https://github.com/popcre/ai-devops/actions/runs/35378581829) | pull_request | success | 1 | 2026-09-18T18:10:07Z | 2026-09-18T18:48:53Z | 38.77 |
| [35378542448](https://github.com/popcre/ai-devops/actions/runs/35378542448) | merge_group | success | 1 | 2026-09-18T18:09:42Z | 2026-09-18T18:24:27Z | 14.75 |
| [35378321979](https://github.com/popcre/ai-devops/actions/runs/35378321979) | pull_request | success | 1 | 2026-09-18T18:07:26Z | 2026-09-18T18:08:04Z | 0.63 |
| [35377497962](https://github.com/popcre/ai-devops/actions/runs/35377497962) | pull_request | failure | 4 | 2026-09-18T17:58:57Z | 2026-09-18T19:18:16Z | 79.32 |
| [35377132500](https://github.com/popcre/ai-devops/actions/runs/35377132500) | pull_request | cancelled | 1 | 2026-09-18T17:55:04Z | 2026-09-18T18:11:58Z | 16.90 |
| [35376729927](https://github.com/popcre/ai-devops/actions/runs/35376729927) | merge_group | failure | 1 | 2026-09-18T17:50:50Z | 2026-09-18T17:56:35Z | 5.75 |
| [35376705276](https://github.com/popcre/ai-devops/actions/runs/35376705276) | pull_request | cancelled | 1 | 2026-09-18T17:50:36Z | 2026-09-18T18:37:10Z | 46.57 |
| [35375197721](https://github.com/popcre/ai-devops/actions/runs/35375197721) | pull_request | success | 1 | 2026-09-18T17:35:00Z | 2026-09-18T17:35:38Z | 0.63 |
| [35374777145](https://github.com/popcre/ai-devops/actions/runs/35374777145) | pull_request | success | 1 | 2026-09-18T17:30:47Z | 2026-09-18T17:31:25Z | 0.63 |
| [35374703309](https://github.com/popcre/ai-devops/actions/runs/35374703309) | pull_request | success | 1 | 2026-09-18T17:30:05Z | 2026-09-18T17:30:45Z | 0.67 |
| [35374304061](https://github.com/popcre/ai-devops/actions/runs/35374304061) | pull_request | success | 1 | 2026-09-18T17:26:02Z | 2026-09-18T17:26:41Z | 0.65 |
| [35374099959](https://github.com/popcre/ai-devops/actions/runs/35374099959) | pull_request | failure | 1 | 2026-09-18T17:23:59Z | 2026-09-18T18:11:29Z | 47.50 |
| [35370876729](https://github.com/popcre/ai-devops/actions/runs/35370876729) | pull_request | success | 1 | 2026-09-18T16:50:51Z | 2026-09-18T16:51:37Z | 0.77 |
| [35370867959](https://github.com/popcre/ai-devops/actions/runs/35370867959) | pull_request | failure | 1 | 2026-09-18T16:50:46Z | 2026-09-18T17:39:41Z | 48.92 |
| [35370530695](https://github.com/popcre/ai-devops/actions/runs/35370530695) | pull_request | failure | 1 | 2026-09-18T16:47:22Z | 2026-09-18T17:21:44Z | 34.37 |
| [35367593513](https://github.com/popcre/ai-devops/actions/runs/35367593513) | pull_request | success | 1 | 2026-09-18T16:17:31Z | 2026-09-18T16:18:24Z | 0.88 |
| [35367333579](https://github.com/popcre/ai-devops/actions/runs/35367333579) | pull_request | success | 1 | 2026-09-18T16:14:57Z | 2026-09-18T16:15:41Z | 0.73 |
| [35367223898](https://github.com/popcre/ai-devops/actions/runs/35367223898) | pull_request | cancelled | 1 | 2026-09-18T16:13:53Z | 2026-09-18T16:52:07Z | 38.23 |
| [35366177536](https://github.com/popcre/ai-devops/actions/runs/35366177536) | pull_request | success | 1 | 2026-09-18T16:03:37Z | 2026-09-18T16:04:09Z | 0.53 |
| [35363810604](https://github.com/popcre/ai-devops/actions/runs/35363810604) | pull_request | success | 1 | 2026-09-18T15:40:02Z | 2026-09-18T16:27:56Z | 47.90 |
