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
| 1 | Multi-form timestamps & dates | delay_s / scheduled_start / actual_start suffer from millis, ISO, dashed dates and Excel serials. |
| 2 | Service-day inference & past-24:00 | Missing start_date and trips that cross midnight produce wrong or missing rows. |
| 3 | Vehicle & status collapse | End rows lack fleet number; first valid start must supply vehicle; last event supplies status. |
| 4 | Fleet-number & trip-id normalisation | Prefixes, leading zeros, `.0` and blanks split or drop matches. |
| 5 | As-of timetable & unscheduled trips | Wrong version or missing extra-trip path loses route and scheduled time. |
| 6 | Incremental key & late rail files | Insert-only + simple key is close but gold’s sensor + merge is more robust. |

---

## 1. Multi-form timestamps and dates

### Your current code (before)

In `transform_update` you only accept pure 10-digit or 13-digit numbers:

```sql
CASE
    WHEN event_time NOT GLOB '*[^0-9]*' AND length(event_time) = 13 THEN CAST(event_time AS INTEGER) / 1000
    WHEN event_time NOT GLOB '*[^0-9]*' AND length(event_time) = 10 THEN CAST(event_time AS INTEGER)
END AS event_epoch
```

Start dates are accepted only as 8-digit or simple `date()`.

### Proposed change (after)

Gold normalises every form before ranking:

- Excel serial dates (30000–80000 → `date('1899-12-30', n || ' days')`)
- Dashed / slashed dates
- ISO text with optional offset (local +7 h when no zone)
- Seconds, milliseconds, microseconds
- Quoted / `.0` Excel artefacts stripped first

Then `event_s` is a clean Unix timestamp used for all ordering and delay math.

### Explanation

- **Before:** ISO strings and Excel serials stay text; ranking by them is wrong, so the “first start” and “last event” are incorrect. Dashed start dates fail the GLOB and fall back to batch_id.
- **After:** every report has a comparable epoch; delay_s = actual_s - scheduled_s is accurate.

**Example input**  
Rail unit sends `event_time = '2026-10-15T08:12:00+07:00'` and `start_date = '2026-10-15'`.

**Your behavior**  
event_epoch stays NULL; start_date may be parsed only if it matches the 8-digit path; the trip is dropped or ranked by load time.

**Gold behavior**  
ISO is converted with the +7 offset; dashed date becomes a proper date; the report participates in first-start / last-event correctly.

**Why it matters**  
“Times as millis or ISO text” (18 %) and “Start dates with dashes” (20.6 %) are the two largest unhandled conditions. They drive the low delay_s and scheduled_start scores.

**What to change**  
Add the full timestamp / date parser (Excel serial, ISO with offset, dashed/slashed) before any ranking window.

---

## 2. Service-day inference and trips past 24:00

### Your current code (before)

```sql
COALESCE(
    CASE WHEN start_date GLOB ... THEN date(...) END,
    date(batch_id)
) AS service_day
```

No nearest-timetable logic. Past-midnight trips are not specially handled.

### Proposed change (after)

Gold builds candidate days from the timetable, then for reports that lack a declared day it picks the candidate whose scheduled departure is nearest the event (within 12 h). Trips whose first_departure ≥ 24:00 belong to the previous service day.

### Explanation

- **Before:** rail reports after midnight with a blank start_date inherit the file’s batch day, which is the calendar day, not the service day.
- **After:** the service day is the one whose timetable departure is closest to the report.

**Example input**  
Trip scheduled 25:10:00 (01:10 next calendar day). Report arrives in the 2026-10-16 file with no start_date.

**Your behavior**  
service_day = 2026-10-16 (or batch day); scheduled time is wrong or missing.

**Gold behavior**  
Infers service_day = 2026-10-15; scheduled_start is the 25:10 departure on that service day.

**Why it matters**  
“The day left off the row” (25 %) and “A trip past 24:00:00” (11.1 %) are explicitly called out. They produce the 1,223 unmatched rows and many wrong delay_s values.

**What to change**  
Add a timetable-driven candidate-day step for null start_date and a ≥24 h departure adjustment.

---

## 3. Vehicle from first start & status from last event

### Your current code (before)

You rank starts separately and take the earliest after 07:00, which is good, but the vehicle filter is strict (exactly 4 digits) and status is taken from the absolute latest normalized_status without the gold packing that prefers non-null vehicle.

### Proposed change (after)

Gold packs the first valid start (event_s + vehicle) and the last event (kind) with a sortable key, then extracts:

```sql
min(CASE WHEN event_kind='start' AND event_s >= service_start THEN ... || vehicle_id END)
max(... || last_kind)
```

Vehicle is recovered even when the end row has no fleet number.

### Explanation

- **Before:** many end rows lose the vehicle; status can flip to a later partial report.
- **After:** vehicle always comes from the earliest valid start; status is the last known event kind mapped to started/completed/cancelled.

**Why it matters**  
vehicle_id is only 68 % correct; “End rows with no fleet number” is 21.6 % of the data.

**What to change**  
Keep the earliest-start window but relax the vehicle pattern and take status from the last non-null event kind.

---

## 4. Fleet-number and trip-id normalisation

### Your current code (before)

```sql
CASE WHEN length(vehicle_id) = 4 AND vehicle_id NOT GLOB '*[^0-9]*'
     THEN CAST(vehicle_id AS TEXT) END
```

Trip ids are zero-padded only when purely numeric and length ≤ 7.

### Proposed change (after)

Gold strips `BUS` / `RAIL` prefixes, leading zeros, spaces, and Excel `.0` before the length check, then keeps the numeric core.

### Explanation

- **Before:** “BUS1234” or “ 0567 ” become NULL; the trip loses its vehicle or fails the join.
- **After:** both collapse to the same canonical id.

**Why it matters**  
“Fleet numbers in other forms” (14 %) and “Trip ids with .0 / blanks” (6.6 % + 5 %).

**What to change**  
Add the prefix / ltrim / `.0` strip before the numeric test.

---

## 5. As-of timetable and unscheduled trips

### Your current code (before)

You join the latest effective_day ≤ service_day, which is close, but you do not keep a full version history with next_day bounds, and unscheduled trips (no timetable row) are only partially recovered via feed route.

### Proposed change (after)

Gold materialises `timetable_versions` and `timetable_entries` with effective_day / next_day, then left-joins. When no entry matches, unscheduled = 1 and route comes from the feed.

### Explanation

- **Before:** a trip retimed or moved mid-week can pick the wrong version; extra trips sometimes lose their route.
- **After:** the version in force on that exact service day is used; extra trips still appear.

**Why it matters**  
“An unplanned extra trip” recovered 0 %; “A trip retimed in a later file” and “A trip moved to a new route” are scored.

**What to change**  
Introduce the version bounds and an explicit unscheduled path.

---

## Recommended pattern (SQL / DAG)

1. Keep history tasks incremental with a stable unique key (event_key / file_key) and a sensor or look-back for the late rail file.
2. Materialise a fully-normalised event stream (canonical trip_id, vehicle_id, event_s, declared_day) and a versioned timetable (effective_day, next_day, departure_s).
3. Resolve service day (declared or nearest), then collapse to one row per (trip_id, service_date) using first-valid-start for actual/vehicle and last-event for status.
4. Final `trip_actuals` is a simple projection that computes delay_s = actual_s - scheduled_s and sets unscheduled = 1 when no timetable entry matched.

Start with the timestamp/date parser and the service-day inference. Those two changes address the largest column gaps (`delay_s`, `scheduled_start`, `actual_start`).
