# Week 7: The Timetable: `dag.sql` vs `gold_submit.sql`

Result [measured]: score 0.7846, rank #5 of 9, +20 points. Rows built 100,792 of 107,965. 1,223 rows matched no record (cost 2,446 points). 5 statements.

Evidence tags: `[measured]` from the README, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data, `[untested]`.

**How the tests were run [estimate].** Synthetic raw tables built from the README conditions, run for 30 nights with the real windows (`trip_updates` 5 nights, `trips` 7 nights) and incremental merge, 3 seeds (about 3,140 trip-days in total). One fix at a time was applied to `dag.sql`. The reference is the generator's own answer key; gold matches it on every column. Numbers show direction and size, not the real score.

## Impact ranking

| # | Area | Measured loss | Synthetic gain, one fix alone (correct cells) |
|---|---|---|---|
| 1 | `first_departure` shapes | `scheduled_start` missed 33,653; `delay_s` missed 44,765 | +2,003 |
| 2 | Rail event words (DEPARTED / ARRIVED) | `status` wrong 5,215; `actual_start`, `vehicle_id` missed | +793 |
| 3 | Trip ids ending in `.0` | 7,173 trips never built (every column) | +763 |
| 4 | `event_time` as ISO text | `actual_start` missed 24,729 | +288 |
| 5 | Fleet number with `BUS-` / `RAIL ` prefix | `vehicle_id` missed 33,414 | +207 |
| 6 | Service day when `start_date` is NULL | rows on the wrong day (1,223 unmatched) | +200 |
| 7 | Latest-status ranking | `status` wrong | +43 |

Single-fix gains overlap, so they do not add up exactly. All seven together: built 3,138 of 3,139, 1 stray row, every column at 3,138 correct except `route_id` at 3,105 (gold has about the same gap).

## 1. `first_departure` only accepts `HH:MM:SS`

- **Your code** (`dag.sql` 185-190): `first_departure GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'`.
- **Gold code** (`gold_submit.sql` 238-259): reads 1-digit hours, a missing seconds part, and hours past 24.
- **Example input:** `7:05:00` and `07:05`. Your code gives a NULL departure, so `scheduled_start` and `delay_s` are NULL.
- **Why it matters:** README "Times in 3 forms in the files" is 38.4% of the stream [measured]. `delay_s` missed 41%, `scheduled_start` missed 31% [measured].
- **Before:** `dag.sql` 185-190, as in "Your code".
- **After:** normalise the text before your check.

```sql
FROM (SELECT trip_id, route_id, service_id, direction_id, trip_headsign,
             CASE WHEN first_departure GLOB '[0-9]:[0-9][0-9]:[0-9][0-9]' THEN '0'||first_departure
                  WHEN first_departure GLOB '[0-9][0-9]:[0-9][0-9]' THEN first_departure||':00'
                  WHEN first_departure GLOB '[0-9]:[0-9][0-9]' THEN '0'||first_departure||':00'
                  ELSE first_departure END AS first_departure,
             feed_version, feed_start_date, batch_id, load_at
      FROM trips_history) AS trips_history
```

- **How it works:** every shape becomes `HH:MM:SS` first, so your existing check and the 25:10:00 handling keep working unchanged.
- **Proof [estimate]:** `scheduled_start` correct 1,904 -> 3,068 of 3,139; `delay_s` 1,652 -> 2,491.

## 2. Rail words for start and end

- **Your code** (244-248): the start list has `departure` but not `departed`; the end list has `arrival` but not `arrived`.
- **Example input:** `DEPARTED`, `ARRIVED`. These become NULL, so the trip has no start, `vehicle_id` and `actual_start` are NULL, and status ranking is distorted.
- **Why it matters:** README "Start and end, in other words" is 14%, recovered 62% [measured].
- **After:** add `'departed'` to the start list and `'arrived'` to the end list.
- **Proof [estimate]:** `status` 2,449 -> 2,711; `vehicle_id` 2,268 -> 2,468; `actual_start` 2,475 -> 2,693.

## 3. Trip ids with `.0`

- **Your code** (167-170 and 212-215): the id must be all digits, so `7041203.0` becomes NULL and the trip is dropped.
- **Why it matters:** unbuilt rows are 7,173 of 107,965 = 6.64% [measured]. README "Trip ids with .0 on the end" is 6.6% [measured]. Read as the same thing [inferred].
- **After:** strip a trailing `.0` in both history reads:

```sql
CASE WHEN trip_id GLOB '*[0-9].0' AND substr(trip_id,1,length(trip_id)-2) NOT GLOB '*[^0-9]*'
     THEN substr(trip_id,1,length(trip_id)-2) ELSE trip_id END
```

- **How it works:** the same fix on both sides, so `trips` and `trip_updates` join again. This also fixes `unscheduled`, which was wrongly 1 when the timetable row was lost.
- **Proof [estimate]:** built 3,084 -> 3,109 of 3,139; `unscheduled` 3,083 -> 3,109.

## 4. `event_time` as ISO text

- **Your code** (257-260): only 10- or 13-digit numbers are read.
- **Example input:** `2026-10-04T02:10:57-07:00` (rail units). Becomes NULL.
- **After:** add one branch to `event_epoch`:

```sql
WHEN event_time GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*'
THEN CAST(strftime('%s', event_time) AS INTEGER)
```

- **How it works:** SQLite reads the offset in the text and converts to UTC.
- **Proof [estimate]:** `actual_start` 2,475 -> 2,559; `status` 2,449 -> 2,534.

## 5. Fleet number prefixes

- **Your code** (241-242): the fleet number must be exactly 4 digits.
- **Example input:** `BUS-2594`, `RAIL 1340`.
- **After:** `ltrim(upper(vehicle_id),'BUSRAIL -')`, then your 4-digit check on the result.
- **Proof [estimate]:** `vehicle_id` 2,268 -> 2,475.
- **Not covered [untested]:** the README also says fleet numbers can have leading zeros. Neither gold nor this fix strips them, and that form was not generated.

## 6. Service day when `start_date` is NULL

- **Your code** (227-237): falls back to `date(batch_id)`. Rail reports after midnight are the ones missing the day, so this is the wrong day exactly when the report crosses midnight.
- **Gold code** (303-333): tries the event's day, the day before and 2 days before, and keeps the day whose scheduled departure is nearest the event.
- **After:** rename that column to `start_day` (NULL when missing), add `transform_trip` to the `depends_on` of `transform_update`, and add:

```sql
day_cand AS (SELECT n.trip_update_key,
       date(date(n.event_epoch,'unixepoch','-7 hours'),'-'||ks.k||' days') AS d,
       abs(n.event_epoch - (CAST(strftime('%s', date(date(n.event_epoch,'unixepoch','-7 hours'),'-'||ks.k||' days')||' 07:00:00') AS INTEGER)
            + CAST(substr(t.first_departure,1,2) AS INTEGER)*3600 + CAST(substr(t.first_departure,4,2) AS INTEGER)*60)) AS dist
     FROM norm_status n CROSS JOIN (SELECT 0 AS k UNION ALL SELECT 1 UNION ALL SELECT 2) ks
     JOIN transform_trip t ON t.trip_id = n.trip_id AND t.first_departure IS NOT NULL
     WHERE n.start_day IS NULL AND n.event_epoch IS NOT NULL),
day_pick AS (SELECT trip_update_key, d, ROW_NUMBER() OVER (PARTITION BY trip_update_key ORDER BY dist, d DESC) AS rn FROM day_cand)
-- final: COALESCE(n.start_day, p.d, date(n.batch_id)) AS service_day
```

- **How it works:** a report with no day is tried against three possible days, and the one that lines up with the timetable wins.
- **Proof [estimate]:** rows matching no record 43 -> 18 alone, and 43 -> 1 with the other fixes.

## 7. Latest status

- **Your code** (290-297): ranks all rows, including ones whose status mapped to NULL.
- **After:** add `WHERE normalized_status IS NOT NULL` inside `ranked_status`.
- **Proof [estimate]:** `status` 2,449 -> 2,492. After fix 2 this matters less.

## Handled correctly in your code
The full rebuild each night covers the late-loaded rail rows and timetable files, because history is keyed and nothing is skipped. The earliest start at or after 07:00 handles unset clocks and relief buses. The timetable version in force and the amended resend are right.

## Recommended pattern
Normalise the text of every column once, in the `transform_*` tasks, before any check or join. Most of the loss is one strict shape check on a column the README lists as having several forms.
