# Week 5 — The Close

## 1) Raw tables

Three nightly-copy tables feed the payments close:

| Table | Contents and retention | Full-table rows | Sample rows |
|---|---|---:|---:|
| `raw_payments` | Daily payment changes; last 7 nights | 281,166 | 11 |
| `raw_fx_rates` | Currency rates per business day; last 2 nights | 350 | 14 |
| `raw_merchants` | Full merchants snapshot; latest copy only | 18,487 | 24 |

Inputs include payment identifiers, amounts in currency minor units, statuses, settlement values, timestamps, JSON metadata, correction/batch markers, FX rates, and merchant country/test status.

### `raw_payments` — sample rows (11)

| payment_id | merchant_id | amount | currency | status | settled | created_at | captured_at | updated_at | metadata | _batch_id | _correction_for | _loaded_at |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| pay_ps8ppu1l | M050484 | 3463 | JPY | captured | 1522 | 2026-09-20 17:29:33+00 | 2026-09-20 19:33:07+00 | 2026-09-20 19:33:07+00 | {"channel": "web", "attempt": 1, "order_ref": "ORD-9385051"} | 2026-09-20 | NULL | 2026-09-21 02:13:50+00 |
| pay_xb7l91vy | M095042 | 17507 | USD | authorized | 0 | 2026-09-20 12:13:27+00 | NULL | 2026-09-20 12:13:27+00 | {"channel": "web", "attempt": 1, "order_ref": "ORD-3237835"} | 2026-09-20 | NULL | 2026-09-21 02:15:24+00 |
| pay_53oh8afo | M034646 | 12611 | EUR | Captured | 5355 | 2026-09-22 11:37:07+00 | 2026-09-22 16:28:13+00 | 2026-09-22 16:28:13+00 | {"channel": "web", "attempt": 1} | 2026-09-22 | NULL | 2026-09-23 02:10:12+00 |
| pay_ps8ppu1l | M050484 | 3463 | JPY | captured | 1941 | 2026-09-20 17:29:33+00 | 2026-09-20 19:33:07+00 | 2026-09-20 19:33:07+00 | {"channel": "web", "attempt": 1, "order_ref": "ORD-9385051"} | 2026-09-22 | NULL | 2026-09-23 02:13:38+00 |
| pay_6rvwidtt | M050484 | 2936 | JPY | captured | 1228 | 2026-09-23 05:58:43+00 | 2026-09-23 09:40:21+00 | 2026-09-23 09:40:21+00 | {"channel": "web", "attempt": 2, "order_ref": "ORD-6115410"} | 2026-09-23 | NULL | 2026-09-24 02:13:42+00 |
| pay_qm0o4man | M034646 | 31443 | EUR | captured | 31443 | 2026-09-24 18:44:19+00 | 2026-09-24 20:22:45+00 | 2026-09-24 20:22:45+00 | {"channel": "pos", "attempt": 1, "order_ref": "ORD-2834038"} | 2026-09-24 | NULL | 2026-09-25 02:13:59+00 |
| pay_53oh8afo | M034646 | 12611 | EUR | Captured | 7256 | 2026-09-22 11:37:07+00 | 2026-09-22 16:28:13+00 | 2026-09-22 16:28:13+00 | {"channel": "web", "attempt": 1} | 2026-09-24 | NULL | 2026-09-25 02:32:13+00 |
| pay_6rvwidtt | M050484 | 2936 | JPY | captured | 1708 | 2026-09-23 05:58:43+00 | 2026-09-23 09:40:21+00 | 2026-09-23 09:40:21+00 | {"channel": "web", "attempt": 2, "order_ref": "ORD-6115410"} | 2026-09-24 | NULL | 2026-09-25 02:33:57+00 |
| pay_0h2ld1wn | M095042 | 70550 | USD | captured | 70550 | 2026-09-26 12:59:06+00 | 2026-09-26 16:39:21+00 | 2026-09-26 16:39:21+00 | {"channel": "pos", "attempt": 1, "order_ref": "ORD-6286975"} | 2026-09-26 | NULL | 2026-09-27 06:07:17+00 |
| pay_1dacjdn3 | M095042 | 2265 | USD | authorized | 0 | 2026-09-27 00:02:59+00 | \N | 2026-09-27 00:02:59+00 | {"channel": "web", "attempt": 2, "order_ref": "ORD-9874699"} | 2026-09-27 | NULL | 2026-09-28 02:13:51+00 |
| pay_1b3qdzdw | M095042 | 4554 | USD | captured | 4554 | 2026-09-27 09:36:29+00 | 2026-09-27 13:14:22+00 | 2026-09-27 13:14:22+00 | {"channel": "app", "attempt": 3, "order_ref": "ORD-1526262"} | 2026-09-27 | NULL | 2026-09-28 02:27:53+00 |

### `raw_fx_rates` — sample rows (14)

| rate_date | currency | usd_rate | _batch_id | _loaded_at |
| --- | --- | --- | --- | --- |
| 2026-09-17 | EUR | 1.0863 | 2026-09-18 | 2026-09-19 02:29:21+00 |
| 2026-09-17 | JPY | 0.006750 | 2026-09-18 | 2026-09-19 02:19:12+00 |
| 2026-09-18 | EUR | 1.0859 | 2026-09-18 | 2026-09-19 02:17:38+00 |
| 2026-09-18 | JPY | 0.006749 | 2026-09-18 | 2026-09-19 02:34:55+00 |
| 2026-09-21 | EUR | 1.0847 | 2026-09-21 | 2026-09-22 02:22:03+00 |
| 2026-09-21 | JPY | 0.006730 | 2026-09-21 | 2026-09-22 02:21:44+00 |
| 2026-09-22 | EUR | 1.0804 | 2026-09-22 | 2026-09-23 02:04:55+00 |
| 2026-09-22 | JPY | 0.006756 | 2026-09-22 | 2026-09-23 02:40:55+00 |
| 2026-09-23 | EUR | 1.0804 | 2026-09-23 | 2026-09-24 02:34:06+00 |
| 2026-09-23 | JPY | 0.006759 | 2026-09-23 | 2026-09-24 02:05:26+00 |
| 2026-09-24 | EUR | 1.0828 | 2026-09-24 | 2026-09-25 02:26:46+00 |
| 2026-09-24 | JPY | 0.006743 | 2026-09-24 | 2026-09-25 02:25:22+00 |
| 2026-09-25 | EUR | 1.0826 | 2026-09-25 | 2026-09-26 02:17:23+00 |
| 2026-09-25 | JPY | 0.006736 | 2026-09-25 | 2026-09-26 02:17:18+00 |

### `raw_merchants` — sample rows (24)

| merchant_id | name | country | is_test | _batch_id | _loaded_at |
| --- | --- | --- | --- | --- | --- |
| M034646 | Merchant 034646 | de | f | 2026-09-20 | 2026-09-21 02:07:24+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-20 | 2026-09-21 02:06:27+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-20 | 2026-09-21 02:20:18+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-21 | 2026-09-22 02:30:46+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-21 | 2026-09-22 02:37:21+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-21 | 2026-09-22 02:07:33+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-22 | 2026-09-23 02:04:41+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-22 | 2026-09-23 02:10:52+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-22 | 2026-09-23 02:30:48+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-23 | 2026-09-24 02:22:09+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-23 | 2026-09-24 02:17:31+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-23 | 2026-09-24 02:32:56+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-24 | 2026-09-25 02:07:35+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-24 | 2026-09-25 02:29:49+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-24 | 2026-09-25 02:32:48+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-25 | 2026-09-26 02:19:31+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-25 | 2026-09-26 02:20:06+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-25 | 2026-09-26 02:24:36+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-26 | 2026-09-27 04:26:36+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-26 | 2026-09-27 04:27:48+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-26 | 2026-09-27 04:31:48+00 |
| M034646 | Merchant 034646 | de | f | 2026-09-27 | 2026-09-28 02:30:51+00 |
| M050484 | Merchant 050484 | JP | f | 2026-09-27 | 2026-09-28 02:24:29+00 |
| M095042 | Merchant 095042 | US | f | 2026-09-27 | 2026-09-28 02:10:11+00 |

## 2) Target table: `fct_payments`

One row per payment, with exactly:

| Column | Requirement |
|---|---|
| `payment_id` | Text key |
| `status` | Latest normalized payment state or null |
| `amount_usd` | USD value, two-decimal numeric or null |
| `settled_usd` | Total settled amount in USD, two decimals |
| `settled_in_period_usd` | Settlement amount for the close period, two decimals |
| `captured_at` | UTC timestamp or null |
| `order_ref` | Last-known metadata order reference or null |
| `merchant_country` | Uppercase country code or null |

Sample rows of the target table: 8 rows.

| payment_id | status | amount_usd | settled_usd | settled_in_period_usd | captured_at | order_ref | merchant_country |
| --- | --- | --- | --- | --- | --- | --- | --- |
| pay_ps8ppu1l | captured | 23.37 | 23.37 | 23.37 | 2026-09-20T19:33:07Z | ORD-9385051 | JP |
| pay_xb7l91vy | authorized | 175.07 | 0.00 | 0.00 | NULL | ORD-3237835 | US |
| pay_53oh8afo | captured | 136.25 | 136.25 | 136.25 | 2026-09-22T16:28:13Z | NULL | DE |
| pay_6rvwidtt | captured | 19.84 | 19.84 | 19.84 | 2026-09-23T09:40:21Z | ORD-6115410 | JP |
| pay_qm0o4man | captured | 340.46 | 340.46 | 340.46 | 2026-09-24T20:22:45Z | ORD-2834038 | DE |
| pay_0h2ld1wn | captured | 705.50 | 705.50 | 705.50 | 2026-09-26T16:39:21Z | ORD-6286975 | US |
| pay_1dacjdn3 | authorized | 22.65 | 0.00 | 0.00 | NULL | ORD-9874699 | US |
| pay_1b3qdzdw | captured | 45.54 | 45.54 | 45.54 | 2026-09-27T13:14:22Z | ORD-1526262 | US |

## 3) Notes from finance

- Exclude payments belonging to test merchants.
- If a daily rate is absent, use the most recent earlier rate.
- A re-landed rate replaces the previous rate for that date.
- The landing's metadata column is 40 characters wide.

## 4) Expected sample output

The sample has **11 payment rows, 14 FX-rate rows, and 24 merchant rows**. The brief shows **8 expected target rows**.

## 5) The schedule

Run the DAG nightly at **03:00 UTC** for 30 nights, **2026-09-18 through 2026-10-17**. The data window closes through **2026-10-12**. The full schedule window ends at 2026-10-18 03:00 UTC. Each run sees only the retained raw-table snapshots; the task schedule may be customized within the window. The full DAG has a 512 MB memory budget and a 10-minute runtime cap.
