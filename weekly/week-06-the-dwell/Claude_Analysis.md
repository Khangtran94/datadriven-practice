# Week 6: The Dwell: `dag.sql` vs `gold_submit.sql`

Result [measured]: score 0.6853, rank #3 of 5, +120 points. Rows built 43,311 of 48,948. Statements 4. 1,104 rows matched no record (cost 2,208 points).

Evidence tags: `[measured]` from the README, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data, `[not available]`, `[untested]`.

**How the tests were run [estimate].** Synthetic raw tables built from the README conditions (about 2,900 `unit_visit` rows, 3 seeds), run night by night with the landing windows (unit_visit 7 nights, tariff_rate 2, line_operator 1) and incremental merge. The gold output is used as the reference because the real answer key is not available. Numbers show direction and size, not the real score.

## Impact ranking

| # | Area | Measured loss | Gap vs gold |
|---|---|---|---|
| 1 | `visit_gkey` rule too strict | 5,637 visits never built (every column lost) | Gold accepts any digit string and the `123.0` form |
| 2 | `bill_to` | missed 37,511 | Partly explained, see section 2 |
| 3 | `gate_out_time` | missed 23,853 | Gold handles 4 timestamp forms that `dag.sql` does not |
| 4 | `visit_state` | wrong 5,055, missed 10,652 | Takes newest row even when NULL; vocabulary incomplete |
| 5 | `storage_usd` / `storage_in_period_usd` | wrong 1,338 / 1,156 | `days_chg` integers only; `tariff_cd` null markers |
| 6 | `booking_ref` | missed 9,915 | camelCase key `bookingRef` not read |

## 1. visit_gkey rule (about 5,637 visits lost)

- **Your code** (dag.sql 101-105): `length(visit_gkey) = 8 AND visit_gkey NOT GLOB '*[^0-9]*'`.
- **Gold code** (73-75): any all-digit string, or the `N.0` form with the `.0` cut off.
- **Example input:** `0012345678` (10 digits, "visit keys with leading zeros") and `12345678.0`. Both are dropped by `dag.sql`.
- **Your behavior / Gold behavior:** dropped / kept.
- **Why it matters:** `visit_gkey` missed is exactly 5,637 = 48,948 - 43,311 [measured]. A dropped visit loses all 8 columns.
- **Before** (dag.sql 101-105): as in "Your code".
- **After:**

```sql
CASE WHEN visit_gkey NOT GLOB '*[^0-9]*' AND visit_gkey <> '' THEN visit_gkey
     WHEN visit_gkey GLOB '*[0-9].0'
          AND substr(visit_gkey, 1, length(visit_gkey) - 2) NOT GLOB '*[^0-9]*'
     THEN substr(visit_gkey, 1, length(visit_gkey) - 2) END AS visit_gkey_n
```

- **How it works:** the length check is removed and one branch is added for the `.0` form. Everything else stays.
- **Note:** neither gold nor this fix merges `0012345678` with `12345678` into one visit. The README says that split is a problem, so merging is a chance to beat gold `[untested]`.
- **Proof [estimate]:** visits built 557/653 -> 645/653 (seed 7); 363 -> 411 of 414 (seed 11); 448 -> 512 of 520 (seed 23).

## 2. bill_to (missed 37,511 = 5,637 unbuilt visits + about 31,874 NULLs)

- **Your code** (798-805): the as-of join uses `v.discharge_terminal_day`. If the discharge time does not parse, the day is NULL, the join finds nothing, `bill_to` is NULL.
- **Gold code** (285): `COALESCE(date(dsch_utc,'+2 hours'), first_day)`, a fallback day.
- **Before:** dag.sql 798-805.
- **After:** add `MIN(COALESCE(restated_day_date, batch_day)) AS first_day` to `visit_attributes` (646-663) and join on `COALESCE(v.discharge_terminal_day, v.first_day)`.
- **How it works:** a visit with no usable discharge time still gets matched to the line snapshot of the first day it was charged.
- **Proof [estimate]:** `bill_to` matches gold 482 -> 502 (seed 7), 324 -> 345 (seed 11), 381 -> 410 (seed 23).
- **Not fully explained.** The real loss (about 74% of built rows NULL) is far larger than synthetic data reproduces. `[inferred]` suspects: the strict shape checks `line_scac` = 4 letters and `bill_to` = `P`+5 digits or 5 digits (591-598). If the real codes differ, everything becomes NULL. The README does not give these formats, so this is not claimed.

## 3. gate_out_time (and every other timestamp)

- **Your code** (243-252, repeated for 3 columns): accepts a trailing `Z` or a sign at position -6. The forms `+0530`, `+08` and a ` UTC` suffix fall to the last branch, get `+08:00` appended, and become NULL.
- **Gold code** (87-93): converts those 4 forms first.
- **Example input:** `2026-10-01 03:30:00+0530`.
- **Why it matters:** README "Times in the sender's offset" 10%, "UTC formatted 3 ways" 8%. A NULL time also breaks the "newest" ordering in section 4.
- **After** (for `dsch_time`, `gate_out_time`, `last_upd_time`; `X` is the column):

```sql
CASE WHEN X LIKE '% UTC' THEN replace(X, ' UTC', '')
     WHEN X GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN X || ':00'
     WHEN X GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]'
          THEN substr(X, 1, length(X) - 2) || ':' || substr(X, -2)
     WHEN X GLOB '*[0-9][+-][0-9][0-9]' THEN X || ':00'
     WHEN upper(substr(X, -1)) = 'Z' OR substr(X, -6, 1) IN ('+','-') THEN X
     ELSE X || '+08:00' END
```

- **How it works:** every form is turned into `+HH:MM` or `Z` before `strftime` reads it. A value with no zone is still treated as port time (+08:00).
- **Proof [estimate]:** `gate_out_time` matches gold 448 -> 535/653 (seed 7), 281 -> 354/414, 357 -> 434/520.

## 4. visit_state

- **Your code** (648): `MAX(CASE WHEN event_rank = 1 THEN visit_state_n END)` takes the newest row even when its state is NULL. The README ("Newest row missing fields") says the newest row often lacks columns that an older row still holds.
- **Vocabulary** (123-141): missing words gold has: `dischgd`, `dischd`, `unloaded`, `holding`, `gatedout`, `gated`, `exited`, `exit`, `departed`, `out`, `transhipped`, `tranship`, `trans`, `ts`.
- **After:**

```sql
substr(MAX(CASE WHEN visit_state_n IS NOT NULL
           THEN printf('%09d',999999999-event_rank)||visit_state_n END),10) AS visit_state
```

plus the words above in the four `IN (...)` lists.

- **How it works:** same "newest non-null" pattern you already use for the other columns, now also for the state.
- **Proof [estimate]:** non-null fix alone 284 -> 385/653; with vocabulary -> 461; with the timestamp fix of section 3 -> 644/644.
- **Open:** README also lists the gate app's own words (`landed`, `delivered`, `restowed`). Neither gold nor `dag.sql` maps them.

## 5. storage_usd and storage_in_period_usd

- **a) `days_chg` integers only** (145-155): `1.0` or `1.5` becomes NULL and the day is not charged. Gold uses REAL (80-83). Fix: accept one `.` and `CAST AS REAL`. [estimate] `storage_usd` matches gold 325 -> 441/653 (seed 7), 225 -> 313, 253 -> 377.
- **b) `tariff_cd`** (143): `NULLIF(tariff_cd,'')` only treats the empty string as null. `\N`, `NULL`, `N/A` stay as a tariff code, the rate join finds nothing, the day prices at 0, and the visit's fallback tariff is never used. Fix: use the same null-marker list as the other columns. [estimate] 325 -> 357, 225 -> 241, 253 -> 265.
- **c) Rounding per day to cents** (716): gold sums in ten-thousandths of a dollar and rounds once (353-359). If rates have more than 2 decimals, each day can differ by up to half a cent. `[inferred]`; synthetic rates had 2 decimals, so no difference was visible.
- **Proof, all fixes of sections 1-5 together [estimate]:** `storage_usd` matches gold 638/644 (seed 7), 410/411, 507/511.

## 6. booking_ref

- **Your code** (193-201, 204-212): looks only for the key `booking_ref`. README: the booking portal writes camelCase (`bookingRef`).
- **Gold code** (131-152): checks both.
- **After:** `COALESCE(json_extract(remarks,'$.booking_ref'), json_extract(remarks,'$.bookingRef'))`, and the same for the text-search branch used when the JSON is cut short.
- **Proof [estimate]:** +20 matching visits on seed 7. The remaining differences come from booking-ref shapes invented in the synthetic data, so no conclusion is drawn about the correct format.

## Not compared

The real formats of `bill_to`, `line_scac`, `booking_ref`. The real score of each fix. The incremental filters (`loaded_ts >= MAX(...)`) in the three history tasks: on synthetic data they lost only 2 visits, so they are ranked low, but real data may differ.

## Suggested order

Sections 1, 3, 4 first (cheap, affect many columns), then 5a, 5b, 6, last 2.

## Checklist for the next SQL week

1. Count rows built vs expected first; a visit dropped by a strict key rule loses every column.
2. Every timestamp column needs all offset forms, not only `Z` and `+HH:MM`.
3. For "newest" values, take the newest non-null per column, not the newest row.
4. Treat null markers (`\N`, `NULL`, `N/A`, `-`) the same way in every text column, including codes used in joins.
5. Read keys in every spelling the README lists (camelCase, `.0`, padding) before validating shape.
