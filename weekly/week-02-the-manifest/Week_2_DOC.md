# Week 2 — The Manifest

## 1) Raw input

The source is a JSON-lines feed from a video-streaming service, with one record per rendition. The feed spans six years and records from three successive encoding tools. It contains inconsistent codec and rendition names, re-encoded titles, replayed batches, and logger-produced lines. Documented input fields include `title_id`, `variant`, `codec`, `bitrate`, `duration`, and `packaged`.

**Sample size:** 10 input lines out of 1,000,000. The full stream has 1,000,000 lines.

Sample input rows: 10 records (of 1,000,000 stream lines). The columns below are the union of fields present in the sample; *not present* means the JSON key is absent, while `NULL` is an explicit JSON null.

| title_id | variant | codec | bitrate | duration | packaged | packager | ingested_at | _batch |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T-0104553 | 240p | h264 | 399 | 10186.24 | 2025-04-09T23:11:50Z | *not present* | *not present* | *not present* |
| T-0104553 | 360p | h264 | 737 | 10186.24 | 2025-04-09T23:25:25Z | shaka-packager/2.6.1 | *not present* | *not present* |
| T-0104553 | 480p | h264 | 943 | 10186.240 | 2025-04-09T23:15:52Z | *not present* | *not present* | *not present* |
|  t-0104553  | 720P | H264 | 3469 | 10186.24 | 2025-04-09T23:34:26Z | *not present* | *not present* | *not present* |
| T-0104553 | 1080p | h264 | 4821 | 10186.24 | 1744243442 | *not present* | *not present* | *not present* |
| T-0112472 | 360p | h264 | NULL | 8090.625 | 2025-01-19T08:37:23Z | *not present* | *not present* | *not present* |
| T-0112472 | 480p | h264 | 1096 | 8090.625 | 2025-01-19T08:41:05Z | *not present* | 2026-03-04T11:00:21Z | *not present* |
| T-0112472 | 720p |  h264 | 3391 | 8090.625 | 2025-01-19T09:04:19Z | *not present* | *not present* | *not present* |
| T-0112472 | 1080p | h265 | 2826 | 8090.625 | 2025-01-19T08:58:53Z | *not present* | *not present* | *not present* |
| T-0112472 | 2160p | h265 | 12682 | 8090.625 | 1737279187 | *not present* | *not present* | 4471 |

## 2) Target table

Produce one normalized row per title rendition with exactly:

| Column | Requirement |
|---|---|
| `title_id` | Uppercase, trimmed title key |
| `rendition` | Canonical resolution label (`240p` through `2160p`) |
| `codec` | One of `h264`, `h265`, `av1`, `vp9`, or null |
| `bitrate_kbps` | Integer or null |
| `duration_s` | Seconds as a three-decimal string or null |
| `packaged_at` | UTC timestamp or null |

Sample expected target rows: 10 rows.

| title_id | rendition | codec | bitrate_kbps | duration_s | packaged_at |
| --- | --- | --- | --- | --- | --- |
| T-0104553 | 240p | h264 | 399 | 10186.240 | 2025-04-09T23:11:50Z |
| T-0104553 | 360p | h264 | 737 | 10186.240 | 2025-04-09T23:25:25Z |
| T-0104553 | 480p | h264 | 943 | 10186.240 | 2025-04-09T23:15:52Z |
| T-0104553 | 720p | h264 | 3469 | 10186.240 | 2025-04-09T23:34:26Z |
| T-0104553 | 1080p | h264 | 4821 | 10186.240 | 2025-04-10T00:04:02Z |
| T-0112472 | 360p | h264 | NULL | 8090.625 | 2025-01-19T08:37:23Z |
| T-0112472 | 480p | h264 | 1096 | 8090.625 | 2025-01-19T08:41:05Z |
| T-0112472 | 720p | h264 | 3391 | 8090.625 | 2025-01-19T09:04:19Z |
| T-0112472 | 1080p | h265 | 2826 | 8090.625 | 2025-01-19T08:58:53Z |
| T-0112472 | 2160p | h265 | 12682 | 8090.625 | 2025-01-19T09:33:07Z |

## 3) Notes from the delivery team

- Keep one row per rendition of a title.
- The latest `packaged_at` wins for each rendition.
- A timestamp without a zone is UTC.
- Ignore `packager`, `ingested_at`, and other feed extras.
- Each output is logged under its job; the job's close line is last.

## 4) Expected sample output

The sample includes **10 input rows** and **10 expected output rows**, shown in Sections 1 and 2.

## 5) Execution schedule

This is a streaming handler challenge, not a calendar-based DAG. `Handler.process(raw)` receives each of 1,000,000 lines in order; `Handler.finalize()` can emit remaining rows. Use Python 3.12 and only the documented standard-library imports. The whole stream has a 10-minute runtime cap.
