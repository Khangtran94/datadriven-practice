# Week 1 — The Handoff

## 1) Raw input

The source is a JSON-lines customer export from a legacy CRM, with one object per customer. It covers a six-year product history and has inconsistent field formats, free-text values, region-specific instances, duplicate integrations, and occasionally truncated lines. Documented fields include `customer_id`, `email`, `signup_ts`, `plan`, `seats`, and `mrr`.

**Sample size:** 10 input lines out of 1,000,000. The full stream has 1,000,000 lines.

Sample input rows: 10 records (of 1,000,000 stream lines). The columns below are the union of fields present in the sample; *not present* means the JSON key is absent, while `NULL` is an explicit JSON null.

| customer_id | email | signup_ts | plan | seats | mrr | ingested_at | source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| C-0104553 | maria.lopez@acme.io | 2022-05-12T00:00:00Z | pro | 12 | 1204.5 | *not present* | *not present* |
| C-0112472 | NULL | 2019-11-02T09:14:00Z | free | 1 | 0.0 | *not present* | *not present* |
| C-0120391 | dev@northwind.co | 2024-01-30T18:02:11Z | team | 18 | 890 | 2026-03-04T11:00:21Z | *not present* |
|  c-0128310  | SAM@KITE.DEV | 1652312400 | Pro | 4 | 312.00 | *not present* | *not present* |
| C-0136229 | priya.shah@globex.com | 2021-06-03T14:22:00Z | team | 25 | 1225.0 | *not present* | *not present* |
| C-0144148 | omar_haddad@initech.net | 2025-02-14T08:00:00Z | enterprise | 120 | 11880.0 | *not present* | *not present* |
| C-0152067 | ivy.chen@gmail.com | 2020-09-09T21:45:13Z | free | NULL | NULL | *not present* | *not present* |
| C-0159986 | Felix.Berg@umbrella.org | 2023-12-01T00:00:00Z | PRO | 7 | 203.00 | *not present* | crm-v3 |
| C-0167905 | NULL | 1700000000 | team | 40 | 1960 | *not present* | *not present* |
| C-0175824 | zoe.park@hooli.xyz | 2018-03-27T16:10:41Z | free | 1 | 0.0 | *not present* | *not present* |

## 2) Target table

Produce one normalized row per customer with exactly:

| Column | Requirement |
|---|---|
| `customer_id` | Uppercase, trimmed customer key |
| `email` | Lowercase, trimmed address or null |
| `signup_at` | UTC timestamp or null |
| `plan` | One of `free`, `pro`, `team`, `enterprise`, or null |
| `seats` | Integer or null |
| `mrr_usd` | USD/month as a two-decimal string or null |

Sample expected target rows: 10 rows.

| customer_id | email | signup_at | plan | seats | mrr_usd |
| --- | --- | --- | --- | --- | --- |
| C-0104553 | maria.lopez@acme.io | 2022-05-12T00:00:00Z | pro | 12 | 1204.50 |
| C-0112472 | NULL | 2019-11-02T09:14:00Z | free | 1 | 0.00 |
| C-0120391 | dev@northwind.co | 2024-01-30T18:02:11Z | team | 18 | 890.00 |
| C-0128310 | sam@kite.dev | 2022-05-11T23:40:00Z | pro | 4 | 312.00 |
| C-0136229 | priya.shah@globex.com | 2021-06-03T14:22:00Z | team | 25 | 1225.00 |
| C-0144148 | omar_haddad@initech.net | 2025-02-14T08:00:00Z | enterprise | 120 | 11880.00 |
| C-0152067 | ivy.chen@gmail.com | 2020-09-09T21:45:13Z | free | NULL | NULL |
| C-0159986 | felix.berg@umbrella.org | 2023-12-01T00:00:00Z | pro | 7 | 203.00 |
| C-0167905 | NULL | 2023-11-14T22:13:20Z | team | 40 | 1960.00 |
| C-0175824 | zoe.park@hooli.xyz | 2018-03-27T16:10:41Z | free | 1 | 0.00 |

## 3) Notes from finance

- Keep one row per customer.
- Interpret ambiguous US dates as month-first.
- A timestamp without a zone is UTC.
- Ignore `ingested_at` and other export bookkeeping.
- Source lines are concatenated strings and may not be valid complete records.

## 4) Expected sample output

The sample includes **10 input rows** and **10 expected output rows**, shown in Sections 1 and 2.

## 5) Execution schedule

This is a streaming handler challenge, not a calendar-based DAG. `Handler.process(raw)` receives each of 1,000,000 lines in order; `Handler.finalize()` can emit remaining rows. Use Python 3.12 and only the documented standard-library imports. The whole stream has a 10-minute runtime cap.
