# Week 3 — The Register

## 1) Raw input

The source is a JSON-lines smart-meter feed. Each record reports energy used and/or a cumulative register for a half-hour interval. Three meter makers have different formats; delayed readings, repeated collector batches, hand-assembled or truncated records, and change-event corrections can occur. Documented fields include `meter_id`, `interval_end`, `kwh`, `register`, and `quality`.

**Sample size:** 10 input lines out of 1,000,000. The full stream has 1,000,000 lines.

Sample input rows: 10 records (of 1,000,000 stream lines). The columns below are the union of fields present in the sample; *not present* means the JSON key is absent, while `NULL` is an explicit JSON null.

| meter_id | interval_end | kwh | register | quality | received_at | collector | _seq |
| --- | --- | --- | --- | --- | --- | --- | --- |
| M-0231257 | 2026-10-29T23:00:00Z | 1.872 | 41310.757 | A | *not present* | *not present* | *not present* |
| M-0144148 | 2026-10-29T23:00:00Z | 0.921 | 19614.204 | A | *not present* | *not present* | *not present* |
| M-0231257 | 2026-10-29T23:30:00Z | 1.51 | 41312.267 | A | 2026-10-29T23:34:12Z | *not present* | *not present* |
| M-0144148 | 2026-10-29T23:30:00Z | 1.996 | 19616.200 | A | *not present* | *not present* | *not present* |
| M-0231257 | 1793318400 | 2.294 | 41314.561 | A | *not present* | *not present* | *not present* |
|   m-0144148 | 2026-10-30T00:00:00Z | 0.989 | 19617.189 | a | *not present* | *not present* | *not present* |
| M-0231257 | 2026-10-30T00:30:00Z | 1.329 | 41315.89 | A | *not present* | C-0000 | *not present* |
| M-0144148 | 2026-10-30T00:30:00Z | 1.057 | 19618.246 | A | *not present* | *not present* | *not present* |
| M-0231257 | 1793322000 | 1.103 | 41316.993 | A | *not present* | *not present* | *not present* |
| M-0144148  | 2026-10-30T01:00:00Z | 1.961 | 19620.207 | A | *not present* | *not present* | 4471093 |

## 2) Target table

Produce one normalized row per meter and interval with exactly:

| Column | Requirement |
|---|---|
| `meter_id` | Uppercase, trimmed meter key |
| `interval_end` | UTC interval-end timestamp |
| `usage_kwh` | Usage as a three-decimal string or null |
| `register_kwh` | Register as a three-decimal string or null |
| `quality` | `actual`, `estimated`, or null |

Sample expected target rows: 10 rows.

| meter_id | interval_end | usage_kwh | register_kwh | quality |
| --- | --- | --- | --- | --- |
| M-0231257 | 2026-10-29T23:00:00Z | 1.872 | 41310.757 | actual |
| M-0144148 | 2026-10-29T23:00:00Z | 0.921 | 19614.204 | actual |
| M-0231257 | 2026-10-29T23:30:00Z | 1.510 | 41312.267 | actual |
| M-0144148 | 2026-10-29T23:30:00Z | 1.996 | 19616.200 | actual |
| M-0231257 | 2026-10-30T00:00:00Z | 2.294 | 41314.561 | actual |
| M-0144148 | 2026-10-30T00:00:00Z | 0.989 | 19617.189 | actual |
| M-0231257 | 2026-10-30T00:30:00Z | 1.329 | 41315.890 | actual |
| M-0144148 | 2026-10-30T00:30:00Z | 1.057 | 19618.246 | actual |
| M-0231257 | 2026-10-30T01:00:00Z | 1.103 | 41316.993 | actual |
| M-0144148 | 2026-10-30T01:00:00Z | 1.961 | 19620.207 | actual |

## 3) Notes from billing

- Keep one row per meter per 30-minute interval.
- For the same interval, an actual read takes precedence over an estimate.
- Ignore `collector`, `received_at`, and other head-end extras.
- Corrections arrive as change events.

## 4) Expected sample output

The sample includes **10 input rows** and **10 expected output rows**, shown in Sections 1 and 2.

## 5) Execution schedule

This is a streaming handler challenge, not a calendar-based DAG. `Handler.process(raw)` receives each of 1,000,000 lines in order; `Handler.finalize()` can emit remaining rows. Use Python 3.12 and only the documented standard-library imports. The stream has a 512 MB memory budget and a 10-minute runtime cap.
