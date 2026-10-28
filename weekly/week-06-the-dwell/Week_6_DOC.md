# Week 6 — The Dwell

## 1) Raw tables

Three nightly-copy tables support the container-terminal billing calculation:

| Table | Contents and retention | Full-table rows | Sample rows |
|---|---|---:|---:|
| `unit_visit` | Visit change log; last 7 nights | 290,765 | 17 |
| `tariff_rate` | Full initial tariff load, then changed rates; last 2 nights | 24 | 2 |
| `line_operator` | Full nightly shipping-line snapshot; latest copy only | 9,213 | 30 |

The data includes visit identifiers and states, container and line identifiers, daily charged days, timestamps, JSON remarks, effective-dated tariff rates, and shipping-line billing/test flags.

### `unit_visit` — sample rows (17)

| visit_gkey | unit_nbr | line_scac | visit_state | tariff_cd | days_chg | dsch_time | gate_out_time | last_upd_time | remarks | _batch_id | _restated_day | _loaded_at |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 97139043 | ZBRU0093353 | FALU | discharged | DRY40 | 0 | 2026-09-27 17:24:32+08 | NULL | 2026-09-27 17:24:32+08 | {"seal": "S5232124", "hazmat": false, "booking_ref": "BK-0509534"} | 2026-09-27 | NULL | 2026-09-28 02:09:36+00 |
| 52781433 | KSTU5842206 | GLNA | discharged | DRY40 | 0 | 2026-09-28 02:16:13+08 | NULL | 2026-09-28 02:16:13+08 | {"seal": "S8171545", "hazmat": false} | 2026-09-27 | NULL | 2026-09-28 02:26:41+00 |
| 10880307 | WLDU6047023 | GLNA | discharged | HC40 | 0 | 2026-09-28 04:59:38+08 | NULL | 2026-09-28 04:59:38+08 | {"seal": "S1767151", "hazmat": false, "booking_ref": "BK-3470806"} | 2026-09-27 | NULL | 2026-09-28 02:28:04+00 |
| 12099687 | MRDU-468649-5 | FALU | discharged | DRY40 | 0 | 2026-09-28 14:49:40+08 | \N | 2026-09-28 14:49:40+08 | {"seal": "S9922198", "hazmat": false, "booking_ref": "BK-7857006"} | 2026-09-28 | NULL | 2026-09-29 02:22:52+00 |
| 94025754 | MRDU8828427 | HANB | discharged | DRY40 | 0 | 2026-09-29 00:44:13+08 | NULL | 2026-09-29 00:44:13+08 | {"seal": "S3776103", "hazmat": false, "booking_ref": "BK-8289088"} | 2026-09-28 | NULL | 2026-09-29 02:40:01+00 |
| 81277157 | ORXU5768141 | FALU | discharged  | DRY40 | 0 | 2026-09-29 12:40:29+08 | NULL | 2026-09-29 12:40:29+08 | {"seal": "S5795809", "hazmat": false} | 2026-09-29 | NULL | 2026-09-30 05:21:18+00 |
| 12099687 | MRDU-468649-5 | FALU | gated_out | DRY40 | 0 | 2026-09-28 14:49:40+08 | 2026-09-30 12:17:39+08 | 2026-09-30 12:17:39+08 | {"seal": "S9922198", "hazmat": false, "booking_ref": "BK-7857006"} | 2026-09-30 | NULL | 2026-10-01 02:09:34+00 |
| 33350664 | CRVU 466100 0 | FALU | discharged | DRY40 | 0 | 2026-09-30 20:58:18+08 | NULL | 2026-09-30 20:58:18+08 | {"seal": "S8276156", "hazmat": true, "booking_ref": "BK-9709503"} | 2026-09-30 | NULL | 2026-10-01 02:16:31+00 |
| 10880307 | WLDU6047023 | GLNA | gated_out | HC40 | 0 | 2026-09-28 04:59:38+08 | 2026-10-01 18:03:19+08 | 2026-10-01 18:03:19+08 | {"seal": "S1767151", "hazmat": false, "booking_ref": "BK-3470806"} | 2026-10-01 | NULL | 2026-10-02 02:08:24+00 |
| 94025754 | MRDU8828427 | HANB | gated_out | DRY40 | 0 | 2026-09-29 00:44:13+08 | 2026-10-02 03:13:12+08 | 2026-10-02 03:13:12+08 | {"seal": "S3776103", "hazmat": false, "booking_ref": "BK-8289088"} | 2026-10-01 | NULL | 2026-10-02 02:15:19+00 |
| 52781433 | KSTU 584220 6 | GLNA | discharged | DRY40 | 1 | 2026-09-28 02:16:13+08 | NULL | 2026-09-28 02:16:13+08 | {"seal": "S8171545", "hazmat": false} | 2026-10-02 | NULL | 2026-10-03 02:26:51+00 |
| 97139043 | ZBRU0093353 | FALU | discharged | DRY40 | 1 | 2026-09-27 17:24:32+08 | NULL | 2026-09-27 17:24:32+08 | {"seal": "S5232124", "hazmat": false, "booking_ref": "BK-0509534"} | 2026-10-02 | NULL | 2026-10-03 02:29:54+00 |
| 52781433 | KSTU 584220 6 | GLNA | discharged | DRY40 | 1 | 2026-09-28 02:16:13+08 | NULL | 2026-09-28 02:16:13+08 | {"seal": "S8171545", "hazmat": false} | 2026-10-03 | NULL | 2026-10-04 02:20:49+00 |
| 81277157 | ORXU5768141 | FALU | gated_out  | DRY40 | 0 | 2026-09-29 12:40:29+08 | 2026-10-03 13:19:40+08 | 2026-10-03 13:19:40+08 | {"seal": "S5795809", "hazmat": false} | 2026-10-03 | NULL | 2026-10-04 02:27:31+00 |
| 97139043 | ZBRU0093353 | FALU | gated_out | DRY40 | 1 | 2026-09-27 17:24:32+08 | 2026-10-03 21:42:21+08 | 2026-10-03 21:42:21+08 | {"seal": "S5232124", "hazmat": false, "booking_ref": "BK-0509534"} | 2026-10-03 | NULL | 2026-10-04 02:31:11+00 |
| 52781433 | KSTU 584220 6 | GLNA | gated_out | DRY40 | -1 | 2026-09-28 02:16:13+08 | 2026-10-04 21:46:06+08 | 2026-10-04 21:46:06+08 | {"seal": "S8171545", "hazmat": false} | 2026-10-04 | NULL | 2026-10-05 02:10:41+00 |
| 33350664 | CRVU 466100 0 | FALU | transshipped | DRY40 | 0 | 2026-09-30 20:58:18+08 | NULL | 2026-10-05 03:49:18+08 | {"seal": "S8276156", "hazmat": true, "booking_ref": "BK-9709503"} | 2026-10-04 | NULL | 2026-10-05 02:40:48+00 |

### `tariff_rate` — sample rows (2)

| tariff_cd | eff_date | rate_usd | _batch_id | _loaded_at |
| --- | --- | --- | --- | --- |
| DRY40 | 2026-09-19 | 22.00 | 2026-09-25 | 2026-09-26 02:05:52+00 |
| HC40 | 2026-09-19 | 24.00 | 2026-09-25 | 2026-09-26 02:10:05+00 |

### `line_operator` — sample rows (30)

| line_scac | line_name | bill_to | test_flag | _batch_id | _loaded_at |
| --- | --- | --- | --- | --- | --- |
| GLNA | Coral Container Line | P83229 | N | 2026-09-25 | 2026-09-26 02:24:28+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-25 | 2026-09-26 02:09:35+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-25 | 2026-09-26 02:16:10+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-09-26 | 2026-09-27 02:15:50+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-26 | 2026-09-27 02:21:14+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-26 | 2026-09-27 02:06:28+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-09-27 | 2026-09-28 02:38:37+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-27 | 2026-09-28 02:31:46+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-27 | 2026-09-28 02:19:25+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-09-28 | 2026-09-29 02:25:19+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-28 | 2026-09-29 02:05:22+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-28 | 2026-09-29 02:05:36+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-09-29 | 2026-09-30 04:40:05+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-29 | 2026-09-30 06:21:39+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-29 | 2026-09-30 05:32:22+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-09-30 | 2026-10-01 02:39:35+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-09-30 | 2026-10-01 02:10:05+00 |
| falu | Atlas Navigation | P42528 | N | 2026-09-30 | 2026-10-01 02:21:52+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-10-01 | 2026-10-02 02:03:03+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-10-01 | 2026-10-02 02:36:25+00 |
| falu | Atlas Navigation | P42528 | N | 2026-10-01 | 2026-10-02 02:03:58+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-10-02 | 2026-10-03 02:06:09+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-10-02 | 2026-10-03 02:10:15+00 |
| falu | Atlas Navigation | P42528 | N | 2026-10-02 | 2026-10-03 02:38:48+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-10-03 | 2026-10-04 02:14:56+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-10-03 | 2026-10-04 02:26:25+00 |
| falu | Atlas Navigation | P42528 | N | 2026-10-03 | 2026-10-04 02:26:21+00 |
| GLNA | Coral Container Line | P83229 | N | 2026-10-04 | 2026-10-05 02:12:13+00 |
| HANB | Tidal Navigation | P10547 | Y | 2026-10-04 | 2026-10-05 02:38:05+00 |
| falu | Atlas Navigation | P42528 | N | 2026-10-04 | 2026-10-05 02:27:08+00 |

## 2) Target table: `storage_charges`

One row per visit, with exactly:

| Column | Requirement |
|---|---|
| `visit_gkey` | Text visit key |
| `unit_nbr` | Uppercase ISO 6346 container identifier without spaces, or null |
| `visit_state` | `discharged`, `held`, `gated_out`, `transshipped`, or null |
| `gate_out_time` | UTC timestamp or null |
| `booking_ref` | Last-seen booking reference from remarks or null |
| `storage_usd` | Total storage charge, two decimals |
| `storage_in_period_usd` | Charge through the close, two decimals |
| `bill_to` | Uppercase bill-to code or null |

Sample rows of the target table: 6 rows.

| visit_gkey | unit_nbr | visit_state | gate_out_time | booking_ref | storage_usd | storage_in_period_usd | bill_to |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 97139043 | ZBRU0093353 | gated_out | 2026-10-03T13:42:21Z | BK-0509534 | 44.00 | 44.00 | P42528 |
| 52781433 | KSTU5842206 | gated_out | 2026-10-04T13:46:06Z | NULL | 22.00 | 22.00 | P83229 |
| 10880307 | WLDU6047023 | gated_out | 2026-10-01T10:03:19Z | BK-3470806 | 0.00 | 0.00 | P83229 |
| 12099687 | MRDU4686495 | gated_out | 2026-09-30T04:17:39Z | BK-7857006 | 0.00 | 0.00 | P42528 |
| 81277157 | ORXU5768141 | gated_out | 2026-10-03T05:19:40Z | NULL | 0.00 | 0.00 | P42528 |
| 33350664 | CRVU4661000 | transshipped | NULL | BK-9709503 | 0.00 | 0.00 | P42528 |

## 3) Notes from billing

- Exclude visits for test lines.
- The terminal day is 06:00–06:00 local time (UTC+8).
- A tariff rate applies until the next effective date.
- A repeated rate for the same effective date replaces its earlier value.
- Gate-app remarks are logged as a line of at most 40 characters.

## 4) Expected sample output

The sample has **17 visit rows, 2 tariff rows, and 30 line-operator rows**. The brief shows **6 expected target rows**.

## 5) The schedule

Run nightly at **03:00 UTC** for 30 nights, **2026-09-25 through 2026-10-24**. The target period closes on **2026-10-19**; the schedule window ends at 2026-10-25 03:00 UTC. Each run sees only retained raw-table snapshots. The full DAG has a 512 MB memory budget and a 10-minute runtime cap.
