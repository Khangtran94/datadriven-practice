# Week 9 — The Basket

You're a data engineer at a grocery delivery app. Customers order items in the app, shoppers scan them into bags, and drivers deliver them. Finance needs one clean row per order showing delivery status, charged item count, subtotal, and tip. Build the table for orders placed from 2026-10-16 through 2026-11-14.

## 1) Raw tables

The challenge provides three raw tables. Column types below are the types documented by the store systems team. Sample values and row order are preserved from the brief.

### `order_events`

An order-service event log with a row each time an order or its tip changes. Read live; the source deletes old rows and retains only the last 6 hours. The full table has 42,594 rows.

| Column | Type | Meaning |
|---|---|---|
| `event_id` | TEXT | The order service's id for the event |
| `order_id` | TEXT | The 8-digit order number |
| `event` | TEXT | `placed`, `delivered`, `cancelled`, `reinstated`, `deleted`, `tip_changed`, `replacement_declined`, or `replacement_approved` |
| `event_at` | TEXT | When it happened, UTC |
| `detail` | TEXT | The tip on `placed` and `tip_changed` events; the scan id on a replacement event |
| `written_at` | TEXT | When the order service wrote the row, UTC |

Sample input: 20 rows. Columns follow the documented source order.

| `event_id` | `order_id` | `event` | `event_at` | `detail` | `written_at` |
|---|---|---|---|---|---|
| `ev_92b7ed96b491` | `27992613` | `placed` | `2026-10-16T11:11:49Z` | `10.00` | `2026-10-16 11:11:50+00` |
| `ev_94b796c38b64` | `27992613` | `delivered` | `2026-10-16T15:34:06Z` | NULL | `2026-10-16 15:34:06+00` |
| `ev_f79ee5949866` | `61727553` | `placed` | `2026-10-16T15:46:08Z` | `10.00` | `2026-10-16 15:46:10+00` |
| `ev_fa744d129eda` | `38406663` | `placed` | `2026-10-16T17:01:46Z` | `5.00` | `2026-10-16 17:01:46+00` |
| `ev_3e8d02a6e3a5` | `61727553` | `replacement_declined` | `2026-10-16T19:19:18Z` | `sc_1f588ecacb60` | `2026-10-16 19:19:18+00` |
| `ev_86d6ded086e6` | `61727553` | `delivered` | `2026-10-16T19:47:36Z` | NULL | `2026-10-16 19:47:36+00` |
| `ev_42784408f47c` | `37970553` | `placed` | `2026-10-16T19:52:54Z` | `7.50` | `2026-10-16 19:52:55+00` |
| `ev_03f5cbcd3d8c` | `38406663` | `delivered` | `2026-10-16T21:56:48Z` | NULL | `2026-10-16 21:56:48+00` |
| `ev_a315e06285a9` | `54838023` | `placed` | `2026-10-16T22:37:48Z` | `15.00` | `2026-10-16 22:37:49+00` |
| `ev_20bcb3f92ca7` | `37970553` | `delivered` | `2026-10-16T23:31:58Z` | NULL | `2026-10-16 23:32:01+00` |
| `ev_035d4d45c956` | `54838023` | `delivered` | `2026-10-17T03:25:20Z` | NULL | `2026-10-17 03:25:21+00` |
| `ev_fbe50f67f23f` | `56469902` | `placed` | `2026-10-17T21:18:13Z` | `15.00` | `2026-10-17 21:18:14+00` |
| `ev_9062b9ddee97` | `38406663` | `tip_changed` | `2026-10-17T21:33:48Z` | `0.00` | `2026-10-17 21:33:49+00` |
| `ev_93ec042de708` | `11133062` | `placed` | `2026-10-17T23:15:23Z` | `12.00` | `2026-10-17 23:15:23+00` |
| `ev_03cdadabad0d` | `11133062` | `cancelled` | `2026-10-17T23:20:23Z` | NULL | `2026-10-17 23:20:23+00` |
| `ev_a1e8b1bb1463` | `34613462` | `placed` | `2026-10-17T23:53:21Z` | `12.00` | `2026-10-17 23:53:21+00` |
| `ev_6f164c322694` | `56469902` | `delivered` | `2026-10-18T01:04:04Z` | NULL | `2026-10-18 01:04:06+00` |
| `ev_da2272f7cc77` | `34613462` | `replacement_declined` | `2026-10-18T02:40:54Z` | `sc_fdcda66df912` | `2026-10-18 02:40:54+00` |
| `ev_a5adc1256981` | `34613462` | `delivered` | `2026-10-18T03:26:46Z` | NULL | `2026-10-18 03:26:47+00` |
| `ev_4c442fbecee8` | `38406663` | `tip_changed` | `2026-10-19T05:59:48Z` | `12.00` | `2026-10-19 05:59:50+00` |

### `scans`

A shopper-app log with one row per item scanned into an order's bags. There is one file per UTC scan day, copied the next morning; only the last 3 nights are retained. The full table has 223,859 rows.

| Column | Type | Meaning |
|---|---|---|
| `scan_id` | TEXT | The shopper app's id for the scan |
| `order_id` | TEXT | The order the item was scanned into |
| `code` | TEXT | Item barcode (UPC) or produce code (PLU) |
| `qty` | TEXT | Quantity; for a by-the-pound item, its weight |
| `weight_lb` | TEXT | Scale weight in pounds, sent by the newer app release |
| `_batch_id` | TEXT | UTC day of the scans in the file |
| `_loaded_at` | TEXT | When the copy job loaded the file, UTC |

Sample input: 10 rows. The last row's `weight_lb` value is the literal text `NULL` in the source sample, not a JSON null.

| `scan_id` | `order_id` | `code` | `qty` | `weight_lb` | `_batch_id` | `_loaded_at` |
|---|---|---|---|---|---|---|
| `sc_1f588ecacb60` | `61727553` | `319393586733` | `1` | NULL | `2026-10-16` | `2026-10-17 05:12:13+00` |
| `sc_1f588ecacb60` | `61727553` | `319393586733` | `1` | NULL | `2026-10-16` | `2026-10-17 05:12:13+00` |
| `sc_a7213f5b4dd6` | `37970553` | `842324956362` | `4` | NULL | `2026-10-16` | `2026-10-17 05:12:13+00` |
| `sc_e39660c6fb77` | `38406663` | `107823261943` | `3` | NULL | `2026-10-16` | `2026-10-17 05:12:13+00` |
| `sc_ef1bca5e10e7` | `27992613` | `318746927032` | `2` | NULL | `2026-10-16` | `2026-10-17 05:12:13+00` |
| `sc_0df47df87f7b` | `54838023` | `3597` | `1` | `2.85` | `2026-10-17` | `2026-10-18 10:05:06+00` |
| `sc_6a29b15ee997` | `54838023` | `3597` | `1` | `2.20` | `2026-10-17` | `2026-10-18 10:05:06+00` |
| `sc_03cb22861965` | `56469902` | `213355012264` | `1` | NULL | `2026-10-18` | `2026-10-19 04:36:32+00` |
| `sc_7d98927f9460` | `56469902` | `032317750200` | `1` | NULL | `2026-10-18` | `2026-10-19 04:36:32+00` |
| `sc_fdcda66df912` | `34613462` | `93572` | `4` | `NULL` (literal text) | `2026-10-18` | `2026-10-19 04:36:32+00` |

### `prices`

A nightly snapshot of the stores' whole price list. Only the latest copy is kept. The full table has 33,555 rows.

| Column | Type | Meaning |
|---|---|---|
| `code` | TEXT | Item UPC or PLU |
| `price` | TEXT | Dollars per item or per pound |
| `sold_by` | TEXT | `each` or `lb` for an item sold by the pound |
| `_loaded_at` | TEXT | When the copy was taken, UTC |

Sample input: 28 rows.

| `code` | `price` | `sold_by` | `_loaded_at` |
|---|---:|---|---|
| `032317750200` | `4.99` | `each` | `2026-10-16 03:56:06+00` |
| `107823261943` | `2.69` | `each` | `2026-10-16 03:56:06+00` |
| `318746927032` | `4.99` | `each` | `2026-10-16 03:56:06+00` |
| `319393586733` | `1.19` | `each` | `2026-10-16 03:56:06+00` |
| `3597` | `0.69` | `lb` | `2026-10-16 03:56:06+00` |
| `842324956362` | `3.09` | `each` | `2026-10-16 03:56:06+00` |
| `93572` | `4.09` | `each` | `2026-10-16 03:56:06+00` |
| `032317750200` | `4.99` | `each` | `2026-10-17 03:53:18+00` |
| `107823261943` | `2.69` | `each` | `2026-10-17 03:53:18+00` |
| `318746927032` | `4.99` | `each` | `2026-10-17 03:53:18+00` |
| `319393586733` | `1.19` | `each` | `2026-10-17 03:53:18+00` |
| `3597` | `0.69` | `lb` | `2026-10-17 03:53:18+00` |
| `842324956362` | `3.09` | `each` | `2026-10-17 03:53:18+00` |
| `93572` | `4.09` | `each` | `2026-10-17 03:53:18+00` |
| `032317750200` | `4.99` | `each` | `2026-10-18 03:49:35+00` |
| `107823261943` | `2.69` | `each` | `2026-10-18 03:49:35+00` |
| `318746927032` | `4.99` | `each` | `2026-10-18 03:49:35+00` |
| `319393586733` | `1.19` | `each` | `2026-10-18 03:49:35+00` |
| `3597` | `0.69` | `lb` | `2026-10-18 03:49:35+00` |
| `842324956362` | `3.09` | `each` | `2026-10-18 03:49:35+00` |
| `93572` | `4.09` | `each` | `2026-10-18 03:49:35+00` |
| `032317750200` | `4.99` | `each` | `2026-10-19 03:49:47+00` |
| `107823261943` | `2.69` | `each` | `2026-10-19 03:49:47+00` |
| `318746927032` | `4.99` | `each` | `2026-10-19 03:49:47+00` |
| `319393586733` | `1.19` | `each` | `2026-10-19 03:49:47+00` |
| `3597` | `0.69` | `lb` | `2026-10-19 03:49:47+00` |
| `842324956362` | `3.09` | `each` | `2026-10-19 03:49:47+00` |
| `93572` | `4.09` | `each` | `2026-10-19 03:49:47+00` |

## 2) Target table: `order_charges`

The output is exactly one row per `order_id`, with these columns in this order:

| Column | Type / constraints | Meaning and correctness |
|---|---|---|
| `order_id` | TEXT, KEY, not null | 8-digit order number. An order support deleted is not an order and must have no row. Match exactly; numeric values are wrong. A second row for the same key costs 2. |
| `status` | enum, not null | `cancelled` if cancelled and not reinstated; otherwise `delivered`. A cancelled order is charged nothing: items, subtotal, and tip are all 0. Allowed values: `delivered`, `cancelled`. |
| `delivered_at` | timestamp, nullable | When the bags were left at the door, in UTC; NULL if cancelled. Source/output representation is ISO 8601 UTC to seconds precision. A different instant is wrong, not close. If the source has no usable value, NULL is correct and scores +1; an incorrect value scores -1. |
| `items` | int, not null | Count each item; count each by-the-pound item as 1. INTEGER, not TEXT. |
| `subtotal` | numeric, not null | Sum of item prices in force when the order was placed. For pound items, multiply weight by price and round to cents. For a store label whose code starts with `2`, digits 7–11 are its price in cents. Numeric value at 2 decimals; an error of one unit in the last place is wrong. |
| `tip` | numeric, not null | The customer's last-set tip in dollars, at 2 decimals. An error of one unit in the last place is wrong. |

Every cell is compared after the DAG's last run. The score is +1 for a right value (including a right NULL), 0 for NULL where the source held a value, -1 for a wrong value, and -2 for an extra row or duplicate key. Types are strict; for example, TEXT in an INTEGER column is wrong.

Expected output: 8 rows. Target columns are in schema order.

| `order_id` | `status` | `delivered_at` | `items` | `subtotal` | `tip` |
|---|---|---|---:|---:|---:|
| `27992613` | `delivered` | `2026-10-16T15:34:06Z` | 2 | `9.98` | `10.00` |
| `61727553` | `delivered` | `2026-10-16T19:47:36Z` | 0 | `0.00` | `10.00` |
| `38406663` | `delivered` | `2026-10-16T21:56:48Z` | 3 | `8.07` | `12.00` |
| `37970553` | `delivered` | `2026-10-16T23:31:58Z` | 4 | `12.36` | `7.50` |
| `54838023` | `delivered` | `2026-10-17T03:25:20Z` | 2 | `3.49` | `15.00` |
| `56469902` | `delivered` | `2026-10-18T01:04:04Z` | 2 | `17.25` | `15.00` |
| `11133062` | `cancelled` | NULL | 0 | `0.00` | `0.00` |
| `34613462` | `delivered` | `2026-10-18T03:26:46Z` | 0 | `0.00` | `12.00` |

## 3) Notes from finance

- The item's price in force is the latest price-list copy loaded before the order was placed. If an item is not yet on the price list, use its first listed price.
- A replacement is charged unless the customer last turned it down. The replacement event's `detail` identifies the scan.
- A repeated delivery of a scan day replaces that day's rows with the version as it was first sent; do not count a replay as additional scans.
- Two releases of the shopper app are in use. The newer release sends pounds in `weight_lb`; the older app release is still used. The schema documents `qty` as quantity or weight for pound items, so account for both formats.
- The order service has three app writers, each using its own words and clock. Do not assume events are already canonical or that timestamps and event ordering are interchangeable; normalize event meaning and use the event time appropriate to each business rule.
- The driver app may save a delivery on the phone until it has signal, so a delivery event can arrive later than the delivery itself.
- The copy job has been patched under pressure more than once. Raw data may contain duplicates or changed/replayed landings; honor the table-specific retention and replay semantics rather than treating every landed row as a new business event.
- A store label code starting with `2` encodes its price in cents in digits 7–11. Price-list `sold_by` values are `each` or `lb`.
- An order that remains cancelled has zero items, subtotal, and tip and a NULL delivery time. A reinstated order is not cancelled. An order support deleted must be omitted from the target.
- The sample is real but intentionally small; the full raw tables contain production history and nightly loads.

## 4) Expected sample output

The sample has 20 `order_events` rows, 10 `scans` rows, and 28 `prices` rows. The expected `order_charges` target contains 8 rows. Detailed target rows are listed under Section 2.

## 5) The schedule

- **Run calendar:** 30 nightly runs from 2026-10-16 through 2026-11-14, at 06:00 UTC (`0 6 * * *`), oldest first. The data window is 2026-10-16 06:00:00 through 2026-11-15 06:00:00 UTC. Each run's logical date (`{{ ds }}`) is the day its data interval starts.
- **Landing visibility:** Each run sees the raw tables as held at that run time. `order_events` retains only 6 hours; `scans` retains the last 3 nights and daily files are copied the next morning; `prices` exposes only the latest nightly copy. Retries, if configured, see the landing at the retry instant.
- **Execution model:** Submit `dag.yml` plus one SQL file per task/table. `dag.yml` declares the schedule, dependencies, materialization, and optional tests. Each SQL file contains one SELECT (or WITH query); tasks may read only their dependencies. Runs follow the task dependency order. A failed task leaves its previous table in place and blocks dependent tasks unless the trigger rule says otherwise.
- **SQL/runtime:** Write SQL accepted by the challenge's supported dialects; SQL is read with shared support for window functions, CTEs, JSON functions, date functions, and shared functions. There is no separate language/runtime requirement.
- **Resource limits:** About 300,000 raw rows total across the three tables, landed through the window. The whole schedule has a 512 MB memory budget and a 10-minute runtime cap; exceeding either stops the run/schedule as an error. Accuracy is scored before efficiency; for equal scores, the DAG doing less work per raw row over the full schedule ranks higher.
- **Challenge timing:** The brief lists the drop as Mon 09 Nov 16:00 UTC, freeze as Sun 15 Nov 16:00 UTC, results at the freeze, and the next drop as Mon 16 Nov 16:00 UTC.
