# Week 7 – The Timetable: dag.sql vs gold_submit.sql

**Your score:** 0.7846 (#5 of 9, top 56%)  
**Your file:** `dag.sql`  
**Top-1 file:** `gold_submit.sql`  
**Rows built:** 100,792 of 107,965  
**Points:** +20  

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

1,223 rows matched no record (cost 2,446 points). The largest column gaps are `delay_s` (only 56 % correct), `scheduled_start` (67 %), and `vehicle_id` (68 %).

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Service-day inference + GTFS >24 h | delay_s and scheduled_start are the worst columns; blank start_date and 25:10:00 times are marked “no”. |
| 2 | Event vocabulary & first-valid-start | status and vehicle_id suffer; relief vehicles and “cancelled then ran” need the first start, not the latest. |
| 3 | Vehicle-id / trip-id normalisation | Fleet numbers with prefixes or leading zeros, trip_ids with `.0` or blanks. |
| 4 | As-of timetable version + unscheduled extras | Newest file is wrong for intermediate days; extra trips must still appear with unscheduled = 1. |
| 5 | Incremental strategy & late rail | Append-only unique key + no sensor drops or duplicates late/re-exported rows. |

---

## 1. Service-day inference and GTFS times past 24:00:00

### Your current code (before)

```sql
COALESCE(
    CASE
        WHEN start_date GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
        THEN date(substr(start_date,1,4) || '-' || substr(start_date,5,2) || '-' || substr(start_date,7,2))
        ...
    END,
    date(batch_id)
) AS service_day
```
and first_departure only accepts `HH:MM:SS` with hours 00-23.

### Proposed change (after)

Gold builds candidate days (declared, local, local-1, local-2) and joins to the timetable, picking the match whose scheduled departure is closest to the event (within 12 h when the day is missing). Times ≥ 24 h are accepted and converted relative to the service day.

### Explanation

- **Before:** blank start_date falls back to batch_id (often wrong after midnight); 25:10:00 is rejected so the trip has no scheduled_start and a nonsense delay.
- **After:** the service day is the one whose timetable departure is nearest the report; >24 h times are anchored correctly.

**Example input**  
Rail report after midnight with start_date = NULL, event_time corresponding to 01:10, timetable departure 25:10:00 on the previous day.

**Your behavior**  
service_day = batch day → wrong scheduled_start or missing row.

**Gold behavior**  
Candidate previous day matches the 25:10 departure → correct service_date and delay.

**Why it matters**  
“The day left off the row” (25 %) and “A trip past 24:00:00” (11 %) are both marked “no”. delay_s is only 56 % correct.

**What to change**  
Add candidate-day matching against the timetable and accept hours ≥ 24 in first_departure / event parsing.

---

## 2. Event vocabulary and first-valid-start ranking

### Your current code (before)

```sql
WHEN lower(event_type) IN ('start','started','begin','began','departure','depart','commence') THEN 'start'
...
-- earliest start with event_epoch >= 07:00 of service_day
```

### Proposed change (after)

Gold normalises a much larger set (DEPARTED, trip_start, ARRIVED, trip_end, CANCELLED, cancelled_trip, …) and ranks the first start that is not before 07:00 on the declared day (or the inferred day for extras).

### Explanation

- **Before:** many real start/end/cancel spellings become NULL; taking any start ≥ 07:00 can pick a relief vehicle.
- **After:** vocabulary is complete; the earliest valid start supplies vehicle_id and actual_start; last non-cancel status wins.

**Example input**  
Start from vehicle 1001 at 07:05, then a relief vehicle 1002 reports another start at 08:30.

**Your behavior**  
May keep 1002 or drop the trip if vocabulary mismatches.

**Gold behavior**  
Keeps the first valid start (1001).

**Why it matters**  
“Start and end, in other words” (14 %) and “A relief bus took over” (4.7 %). vehicle_id is only 68 % correct.

**What to change**  
Expand the CASE lists and rank starts by event_epoch ASC with a floor at service-day 07:00.

---

## 3. Vehicle-id and trip-id normalisation

### Your current code (before)

```sql
CASE WHEN length(vehicle_id) = 4 AND vehicle_id NOT GLOB '*[^0-9]*'
     THEN CAST(vehicle_id AS TEXT) END AS vehicle_id
```
and trip_id only accepts pure digits of length 1-7.

### Proposed change (after)

Gold strips BUS/RAIL prefixes, leading zeros, `.0` spreadsheet artefacts, and blanks; accepts more length variants.

### Explanation

- **Before:** “BUS 1001”, “01001”, “7041203.0” become NULL → unscheduled or dropped.
- **After:** canonical numeric id.

**Why it matters**  
“Fleet numbers in other forms” (14 %) and “Trip ids with .0 on the end” / “with blanks”.

**What to change**  
Add prefix stripping, ltrim of zeros, and `.0` removal before the length/digit checks.

---

## 4. As-of timetable version and unscheduled extras

### Your current code (before)

You pick the latest effective_day ≤ service_day that matches service_id. Unscheduled trips still appear if they have a transform_update row, but route falls back to the feed only when no schedule match exists.

### Proposed change (after)

Gold materialises timetable_versions / timetable_entries with next_day, then in resolved_events prefers the scheduled route when a match exists and sets unscheduled = 1 otherwise. Extra trips are recovered even with no timetable row.

### Explanation

- **Before:** intermediate days can pick the wrong version; some extras are dropped when the day inference fails.
- **After:** the version in force on that exact service day is used; extras keep the feed route and unscheduled = 1.

**Why it matters**  
“An unplanned extra trip” is 0 % recovered. scheduled_start is only 67 % correct.

**What to change**  
Keep history of every version and select the one whose effective range covers the service day; always emit the extra-trip row.

---

## 5. Incremental strategy and late rail

### Your current code (before)

```sql
LEFT JOIN {{ this }} AS x ON x.trip_update_key = d.trip_update_key
WHERE x.trip_update_key IS NULL
```
(append-only) and no sensor.

### Proposed change (after)

Gold uses `incremental_strategy: merge` on a stable `event_key`, a rail_ready sensor (soft_fail, 12 h timeout), and `trigger_rule: none_failed`.

### Explanation

- **Before:** re-exported or corrected rows are ignored; late rail files after the run has started are skipped.
- **After:** corrections are upserted; the sensor waits for the rail feed.

**Why it matters**  
“Rail rows after the run began”, “A file sent again, amended”, “Old rows sent in a newer file”.

**What to change**  
Switch to merge on a content-stable key and add the sensor (or a sufficient lookback).

---

## Recommended pattern (SQL / DAG)

1. History tasks: stable event_key / file_key, merge strategy, full null-as-text + id normalisation.
2. Intermediate views: timetable_versions (effective ranges), resolved_events (candidate-day matching + first-valid-start).
3. Final trip_actuals: simple aggregation of the resolved events for the scoring window, computing delay as actual_start_epoch − scheduled_s.

Start with service-day inference and the expanded event/vehicle normalisation. Those two changes address the largest column gaps (`delay_s`, `scheduled_start`, `vehicle_id`).
