# Week 7 — The Timetable: Submission Review

- **Challenge type:** SQL / DAG (SQLite SQL executed through the repository's DAG runner)
- **Authoritative submission:** `dag.sql` (the README says the graded DAG is in this file)
- **Reference:** `gold_submit.sql`
- **Target output:** `trip_actuals`, one row per `(trip_id, service_date)`
- **Target date range:** 2026-10-02 through 2026-10-31
- **Score:** 0.7846
- **Rank:** #5 of 9 (top 56%)
- **Rows built:** 100,792 of 107,965
- **Work per raw row:** 1.0× median
- **Statements:** 5
- **Scored:** 2026-11-01

The README reports that 1,223 rows matched no record and cost 2,446 points. The column-level results and condition-level recovery figures below are also copied from the README. No separate evaluator execution log was present in the inspected files, so this review does not attribute a particular runtime failure to a task.

## 1. Executive summary

Your DAG has a sensible basic shape: normalize timetable rows, normalize update rows, then aggregate by trip and service day. It uses window functions to select the latest status and earliest start, and it chooses the latest applicable timetable version. Those are useful foundations.

The main difference from the reference is the data model between raw events and final trips. Your implementation treats the raw event's declared date (or file date) as its service day and then groups directly. The reference preserves event history, resolves a service day against timetable candidates, resolves each event against the timetable version in force, and only then aggregates to a trip-day row.

That difference matters for the challenge's explicit cases: reports after midnight with no service date, extra trips, amended files, late reports, variable timestamp and clock formats, and trips that cross file boundaries.

### Impact ranking

| Priority | Issue | Evidence / location | Likely impact | Recommended change |
|---|---|---|---|---|
| 1 | Missing service-day inference for reports without a declared date | `dag.sql`, `transform_update`, `service_day`; compared with reference `resolved_events` | High: wrong trip-day key or omitted rows, especially after midnight | Keep declared date separate; resolve missing dates against timetable departures on candidate days |
| 2 | Event timestamp parser rejects ISO timestamp text | `dag.sql`, `transform_update`, `event_epoch` | High: missing/wrong actual start, status ordering and delay | Parse seconds, milliseconds and ISO timestamps with explicit timezone handling |
| 3 | Fixed-position timetable clock parser | `dag.sql`, `transform_trip`, `first_departure`; downstream `scheduled_dt` | High: wrong or missing scheduled departure | Parse variable-width hours/minutes/seconds and numeric spreadsheet clock values into seconds |
| 4 | Mutable composite event key plus insert-only history | `trip_updates_history`, `trip_update_key`, `merge_incremental` | High: amended event versions can coexist instead of reconciling | Use stable `event_key` (prefer report ID) and merge latest version |
| 5 | Trip IDs with spreadsheet decimal suffix are not normalized | `transform_trip` and `transform_update` numeric-only ID expressions | High for affected rows: timetable join misses | Remove a terminal `.0` only when the fractional part is all zero; trim whitespace and preserve identifier semantics |
| 6 | Vehicle parser accepts only exactly four digits | `transform_update`, `vehicle_id` | Medium–high: missing first-start vehicle | Normalize recognized prefixes and whitespace; retain leading zeros |
| 7 | Event vocabulary and cancellation precedence | `transform_update`, `norm_status` | Medium–high: missed event types or wrong final state | Normalize supplier vocabulary; let explicit event type take precedence over relationship fallback |
| 8 | No explicit output date filter | `trip_actuals`, `keys` / `final_rows` | Medium: output can include out-of-window history if present | Restrict target service dates to the contract window |
| 9 | DAG lacks the reference's feed-readiness sensor and explicit history stages | DAG header and task dependencies | High for late-arriving feed files, subject to runner semantics | Add readiness gate and timetable/event resolution stages; retain runner-specific scheduling semantics |

These are ranked by likely correctness impact based on the task contract and code comparison. The README's aggregate feedback does not prove how many points each individual issue caused.

## 2. What the evaluator feedback says

### Output-column feedback

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `delay_s` | 56% | 2,483 | 44,765 |
| `scheduled_start` | 67% | 1,618 | 33,653 |
| `vehicle_id` | 68% | 1,533 | 33,414 |
| `actual_start` | 76% | 1,695 | 24,729 |
| `status` | 80% | 5,215 | 16,175 |
| `route_id` | 93% | 181 | 7,173 |
| `trip_id` | 93% | 0 | 7,173 |
| `service_date` | 93% | 0 | 7,173 |
| `unscheduled` | 93% | 0 | 7,173 |

### Condition-level feedback

The README says these conditions were not handled as well as the rest of the run:

- Start dates with dashes: 72% recovered.
- Times as milliseconds or ISO text: 67%.
- Alternate start/end vocabulary: 62%.
- Unplanned extra trip: 0%.
- Fleet numbers in other forms: 75%.
- Departure times after 24:00:00: 73%.
- Service day omitted from event: 64%.
- Left early: 79%.

It marks several other conditions as handled, including duplicate rows in a file, NULL written as text, late exports, trip retiming, events reported across two files, and a timetable file amended and resent. These are aggregate results; they should not be interpreted as proof that every row in each condition is correct.

The strongest immediate signal is the low correctness for `delay_s`, `scheduled_start`, and `actual_start`. Delay depends on both scheduled and actual timestamps, so timestamp parsing and schedule matching should be addressed before tuning the final aggregation.

## 3. Findings and teaching review

### Finding 1 — A missing service date needs timetable-aware inference

**Evidence:** `dag.sql`, `transform_update` CTE, service-day expression (around lines 227–237). The README explains that rail devices may omit the service day after midnight and that the candidate day must be inferred from the timetable departure nearest the report.

#### Code before — my current implementation

Actual code from `dag.sql`:

```sql
COALESCE(
    CASE
        WHEN start_date GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
        THEN date(substr(start_date,1,4) || '-' ||
                  substr(start_date,5,2) || '-' ||
                  substr(start_date,7,2))
        WHEN start_date GLOB '????/??/??'
        THEN date(replace(start_date, '/', '-'))
        WHEN date(start_date) IS NOT NULL
        THEN date(start_date)
    END,
    date(batch_id)
) AS service_day
```

The downstream CTE filters out rows without a resolved day:

```sql
FROM clear
WHERE trip_id IS NOT NULL
  AND service_day IS NOT NULL
```

#### Concrete scenario

A timetable trip departs at 25:10:00 on service day 2026-10-10. That departure occurs at 01:10 on calendar day 2026-10-11, but it still belongs to service day 2026-10-10. If the report has no `start_date` and its file is dated 2026-10-11, the current fallback assigns 2026-10-11.

This is not a safe inference: the file date identifies the file, not necessarily the service day of the trip.

#### Reference behavior

The reference keeps `declared_day` distinct from the inferred date. In `resolved_events`, it derives a local calendar day from the event epoch, considers that day and the preceding candidate days, joins each candidate to the timetable version valid on that date, and ranks timetable matches by distance from the event time. For an unscheduled trip it falls back to the start event's inferred local day.

#### Code after — proposed change

First, replace the current `service_day` expression with a declared-date field. Do not silently turn the batch date into a declared service date:

```sql
CASE
    WHEN start_date GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
     AND date(substr(start_date,1,4) || '-' ||
              substr(start_date,5,2) || '-' ||
              substr(start_date,7,2)) IS NOT NULL
    THEN date(substr(start_date,1,4) || '-' ||
              substr(start_date,5,2) || '-' ||
              substr(start_date,7,2))
    WHEN date(start_date) IS NOT NULL
    THEN date(start_date)
END AS declared_day
```

Then move service-day resolution out of `transform_update` into a separate task after event and timetable normalization. The following is a concrete SQLite CTE pattern; it assumes `event_epoch` is a valid UTC epoch and `timetable_entries` exposes `trip_id, route_id, service_id, departure_s, effective_day, next_day`:

```sql
-- Replace the old direct service_day assignment/grouping with this
-- resolution stage. Keep unmatched events for the unscheduled branch.
WITH source AS MATERIALIZED (
    SELECT *,
           date(event_epoch, 'unixepoch', '-7 hours') AS local_day
    FROM normalized_updates
),
candidate_days AS (
    SELECT *, coalesce(declared_day, local_day, batch_day) AS candidate_day
    FROM source
    UNION ALL
    SELECT *, date(local_day, '-1 day') AS candidate_day
    FROM source
    WHERE declared_day IS NULL AND local_day IS NOT NULL
    UNION ALL
    SELECT *, date(local_day, '-2 days') AS candidate_day
    FROM source
    WHERE declared_day IS NULL AND local_day IS NOT NULL
),
matched AS (
    SELECT c.*,
           t.route_id AS scheduled_route,
           t.trip_id AS scheduled_trip_id,
           t.departure_s,
           CAST(strftime('%s', c.candidate_day || ' 07:00:00') AS INTEGER)
               + t.departure_s AS scheduled_s,
           row_number() OVER (
               PARTITION BY c.event_key
               ORDER BY (t.trip_id IS NOT NULL) DESC,
                        CASE WHEN c.declared_day IS NOT NULL THEN 0
                             ELSE abs(
                               c.event_epoch -
                               (CAST(strftime('%s',
                                  c.candidate_day || ' 07:00:00') AS INTEGER)
                                + t.departure_s)
                             )
                        END,
                        c.candidate_day DESC
           ) AS match_rank
    FROM candidate_days c
    LEFT JOIN timetable_entries t
      ON t.trip_id = c.trip_id
     AND c.candidate_day >= t.effective_day
     AND c.candidate_day < t.next_day
     AND (
          t.service_id NOT IN ('WKD','SAT','SUN')
          OR (t.service_id = 'WKD'
              AND strftime('%w', c.candidate_day) BETWEEN '1' AND '5')
          OR (t.service_id = 'SAT'
              AND strftime('%w', c.candidate_day) = '6')
          OR (t.service_id = 'SUN'
              AND strftime('%w', c.candidate_day) = '0')
     )
     AND (
          c.declared_day IS NOT NULL
          OR abs(
              c.event_epoch -
              (CAST(strftime('%s',
                 c.candidate_day || ' 07:00:00') AS INTEGER)
               + t.departure_s)
          ) <= 43200
     )
)
SELECT *
FROM matched
WHERE match_rank = 1;
```

The surrounding task should assign `service_date = candidate_day` when a timetable match exists. For unmatched extra trips, derive the service date from the earliest valid start event's local date, not from an arbitrary report's file date. Preserve event history until that start can be identified.

**Root cause:** The current transformation collapses a missing service date too early, before it has the timetable context needed to infer it.

**Expected behavior:** The 25:10:00 example resolves to 2026-10-10. A trip with no timetable match remains eligible for the unscheduled output path.

**Trade-off and edge cases:** Candidate expansion creates up to three candidates per event, increasing intermediate rows. Keep the candidate window narrow and use the timetable key/date predicates. Test ties between candidate days, a missing event timestamp, a declared date that conflicts with event time, weekday service rules, and genuinely unscheduled extra trips.

### Finding 2 — Event timestamps only accept 10- and 13-digit numeric strings

**Evidence:** `dag.sql`, `transform_update`, `event_epoch` (around lines 258–260). README: 18.0% of tables contain milliseconds or ISO text; the latter can include local timestamps with offsets.

#### Code before — my current implementation

```sql
-- epoch seconds (supports 10-digit seconds and 13-digit milliseconds)
CASE
    WHEN event_time NOT GLOB '*[^0-9]*'
         AND length(event_time) = 13
    THEN CAST(event_time AS INTEGER) / 1000
    WHEN event_time NOT GLOB '*[^0-9]*'
         AND length(event_time) = 10
    THEN CAST(event_time AS INTEGER)
END AS event_epoch
```

The current expression returns NULL for ISO strings. It also has no explicit branch for a device clock that has not yet been set; the README describes such reports as 1970/1980 timestamps.

#### Reference behavior

The reference normalizes numeric values by magnitude (seconds, milliseconds, microseconds, nanoseconds) and parses ISO timestamp text. For ISO text it distinguishes an explicit timezone from local wall-clock text and applies the agency's UTC offset when needed.

#### Code after — proposed change

Use a dedicated parser CTE so each raw value is normalized once. This example covers the documented seconds, milliseconds, and ISO timestamp forms; keep the invalid/implausible-clock policy explicit rather than silently converting every parseable timestamp:

```sql
WITH timestamp_input AS (
    SELECT *,
           trim(event_time) AS event_time_text
    FROM cleaned_updates
),
timestamp_parsed AS (
    SELECT *,
      CASE
        WHEN event_time_text GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]'
          THEN CAST(event_time_text AS INTEGER)
        WHEN length(event_time_text) = 13
         AND event_time_text NOT GLOB '*[^0-9]*'
          THEN CAST(event_time_text AS INTEGER) / 1000
        WHEN event_time_text GLOB '????-??-??T??:??:??*'
         AND datetime(event_time_text) IS NOT NULL
          THEN CAST(strftime('%s', event_time_text) AS INTEGER)
        WHEN event_time_text GLOB '????-??-?? ??:??:??*'
         AND datetime(event_time_text) IS NOT NULL
          THEN CAST(
              strftime('%s', datetime(event_time_text, '+7 hours'))
              AS INTEGER
          )
      END AS parsed_epoch
    FROM timestamp_input
)
SELECT *,
       CASE
         WHEN parsed_epoch BETWEEN
              CAST(strftime('%s', '2000-01-01') AS INTEGER)
              AND CAST(strftime('%s', '2100-01-01') AS INTEGER)
         THEN parsed_epoch
       END AS event_epoch
FROM timestamp_parsed;
```

This is a proposed baseline, not a drop-in complete ISO parser: the production replacement must explicitly recognize timezone suffixes such as `Z`, `-07:00`, and `-0700`, and avoid adding seven hours to timestamps that already carry an offset. The broad validity range is an example policy; confirm the acceptable operational range with the task's device-clock rules before adopting it. If the challenge expects a 1970/1980 event to remain as an event but not count as a valid departure, retain its raw/parsed value and exclude it only from the appropriate actual-start selection.

**Why it matters:** `event_epoch` drives first-start selection, last-event ordering, actual_start, delay, and service-day inference. A NULL or misinterpreted epoch can affect several output columns simultaneously.

**Trade-off and edge cases:** Parsing strings costs more than casting integers. Parse once in a materialized normalization stage. Test seconds, milliseconds, ISO UTC, ISO with positive/negative offsets, local ISO without offset, malformed strings, NULL markers, and implausible device clocks.

### Finding 3 — Fixed-position timetable parsing breaks documented clock formats

**Evidence:** `dag.sql`, `transform_trip`, `first_departure` (around lines 186–190), and `applicable_schedule` (around lines 336–345). README explicitly states that GTFS permits one-digit hours and that one export omits seconds. It also identifies 25:10:00-style service times.

#### Code before — my current implementation

```sql
CASE
    WHEN first_departure GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'
     AND CAST(substr(first_departure, 4, 2) AS INTEGER)
         BETWEEN 0 AND 59
     AND CAST(substr(first_departure, 7, 2) AS INTEGER)
         BETWEEN 0 AND 59
    THEN first_departure
END AS first_departure
```

The schedule conversion later assumes the hour starts at character 1 and is exactly two characters:

```datetime(
    k.service_day,
    '+7 hours',
    '+' || CAST(substr(s.first_departure, 1, 2) AS INTEGER) || ' hours',
    '+' || CAST(substr(s.first_departure, 4, 2) AS INTEGER) || ' minutes',
    '+' || CAST(substr(s.first_departure, 7, 2) AS INTEGER) || ' seconds'
) AS scheduled_dt
```

For `7:05:00`, the substring positions do not identify hour/minute/second correctly. `07:05` is rejected. A clock value represented as a spreadsheet fraction is also rejected.

#### Reference behavior

The reference separates hour, minute, and second components, accepts one-to-three digit hours, permits omitted seconds, handles AM/PM forms, and converts numeric spreadsheet fractions into seconds after midnight. The resulting `departure_s` is then added to the service-day UTC anchor (agency midnight is 07:00 UTC).

#### Code after — proposed change

Replace the fixed-width validation and all downstream substring arithmetic with one normalized `departure_s` value:

```sql
-- Input is normalized to text first. Split into clock components.
WITH clock_parts AS (
    SELECT *,
           lower(replace(trim(first_departure), ' ', '')) AS clock_text,
           CASE WHEN instr(lower(trim(first_departure)), ':') > 0
                THEN substr(lower(replace(trim(first_departure), ' ', '')),
                            1,
                            instr(lower(replace(trim(first_departure), ' ', '')), ':') - 1)
           END AS hour_text
    FROM cleaned_trips
),
clock_values AS (
    SELECT *,
           CAST(hour_text AS INTEGER) AS hour_n,
           CAST(substr(clock_text, instr(clock_text, ':') + 1, 2) AS INTEGER) AS minute_n,
           CASE
             WHEN instr(substr(clock_text, instr(clock_text, ':') + 1), ':') > 0
             THEN CAST(substr(clock_text,
                    instr(clock_text, ':') + 1 +
                    instr(substr(clock_text, instr(clock_text, ':') + 1), ':'),
                    2) AS INTEGER)
             ELSE 0
           END AS second_n
    FROM clock_parts
    WHERE clock_text GLOB '[0-9]*:[0-9]*'
)
SELECT *,
       CASE
         WHEN hour_n BETWEEN 0 AND 167
          AND minute_n BETWEEN 0 AND 59
          AND second_n BETWEEN 0 AND 59
         THEN hour_n * 3600 + minute_n * 60 + second_n
       END AS departure_s
FROM clock_values;
```

Add a separate guarded branch for numeric spreadsheet fractions (valid values from 0 inclusive to 1 exclusive for a time-of-day fraction) and a separate AM/PM conversion if those forms are in the actual source. Do not coerce a numeric-looking trip clock outside the documented spreadsheet range into a clock. The reference uses `departure_s` for all later calculations; follow that pattern:

```sql
-- In applicable_schedule, replace the fixed-position datetime expression:
datetime(
    k.service_day,
    '+7 hours',
    '+' || CAST(s.departure_s / 3600 AS INTEGER) || ' hours',
    '+' || CAST((s.departure_s % 3600) / 60 AS INTEGER) || ' minutes',
    '+' || CAST(s.departure_s % 60 AS INTEGER) || ' seconds'
) AS scheduled_dt
```

**Worked example:** `7:05:00` becomes 25,500 seconds. Adding that to the service-day anchor (00:00 local = 07:00 UTC) gives 14:05 UTC. A `25:10:00` service time becomes 90,600 seconds and resolves to 01:10 UTC on the next calendar day while remaining on the original service date.

**Trade-off and edge cases:** Normalize once rather than repeatedly parsing text. Validate 1-, 2-, and 3-digit hours; omitted seconds; malformed minute/second values; AM/PM; spreadsheet fractions; and values above 24 hours.

### Finding 4 — Event history uses a mutable composite key and insert-only anti-join

**Evidence:** `dag.sql`, `trip_updates_history`, composite `trip_update_key` (around lines 58–66) and `merge_incremental` (around lines 73–96). The README describes amended/re-sent files, old reports arriving in newer files, reports spanning files, and late end events.

#### Code before — my current implementation

```sql
COALESCE(r.update_id, '') || '|' ||
COALESCE(r.trip_id, '') || '|' ||
COALESCE(r.start_date, '') || '|' ||
COALESCE(r.route_id, '') || '|' ||
COALESCE(r.vehicle_id, '') || '|' ||
COALESCE(r.event_type, '') || '|' ||
COALESCE(r.schedule_relationship, '') || '|' ||
COALESCE(r.event_time, '') || '|' ||
COALESCE(r.feed, '') AS trip_update_key
```

The history query ranks by this composite key and only inserts keys not already present:

```sql
SELECT d.*
FROM dedup AS d
LEFT JOIN {{ this }} AS x
  ON x.trip_update_key = d.trip_update_key
WHERE x.trip_update_key IS NULL
```

This removes exact repeats when all key fields match. But if the same report ID is amended and its event time, route, vehicle, or relationship changes, the composite key changes too. The old and corrected versions can both remain in history.

#### Reference behavior

The reference constructs `event_key` from the stable `update_id` when available (with a fallback identity for missing IDs), unions incoming rows with the existing history rows for those keys, ranks by load order and completeness, and uses an incremental merge keyed by `event_key`.

#### Code after — proposed change

At the DAG level, change the history task to merge on a stable key:

```yaml
trip_updates_history:
  materialized: incremental
  depends_on:
    - trip_updates
    - rail_ready
  incremental_strategy: merge
  unique_key:
    - event_key
  trigger_rule: none_failed
```

Replace the mutable composite identity with a stable report identity, then reconcile the incoming and stored version:

```sql
WITH incoming AS (
    SELECT
        coalesce(
            update_id,
            '@' || json_array(
                trip_id, declared_day, event_kind, event_epoch,
                vehicle_id, feed, batch_day
            )
        ) AS event_key,
        *
    FROM normalized_updates
),
candidates AS (
    SELECT * FROM incoming
    {% if is_incremental() %}
    UNION ALL
    SELECT h.*
    FROM {{ this }} h
    JOIN (SELECT DISTINCT event_key FROM incoming) i
      ON i.event_key = h.event_key
    {% endif %}
),
ranked AS (
    SELECT *,
           row_number() OVER (
               PARTITION BY event_key
               ORDER BY loaded_ord DESC,
                        (event_epoch IS NOT NULL) DESC,
                        (vehicle_id IS NOT NULL) DESC,
                        (route_id IS NOT NULL) DESC
           ) AS rn
    FROM candidates
)
SELECT *
FROM ranked
WHERE rn = 1;
```

The fallback key is intentionally not based only on trip and service day: multiple legitimate events can exist for one trip/day. Verify the fallback identity against the source's event semantics. Preserve distinct start/end/cancel events, and do not collapse reports simply because they refer to the same trip.

**Why it matters:** The history table is the foundation for later reconciliation. If corrections are stored as unrelated events, latest-status selection can choose the wrong event and a trip's final state may not reflect the corrected report.

**Trade-off and edge cases:** Merge requires a genuinely stable unique key and a deterministic winner. Test identical duplicate polls, same-ID amended rows, missing IDs, two distinct events for the same trip, late-arriving end events, and rerunning the same batch. The reference's `loaded_ord` is a publication/load ordering signal; it should not be confused with event time.

### Finding 5 — Trip ID and vehicle normalization are narrower than the source contract

**Evidence:** `dag.sql`, `transform_trip` and `transform_update` (around lines 167–170, 212–216, and 241–243). README calls out spreadsheet `.0` suffixes, blank-padded IDs, and fleet numbers with leading zeros, blanks, or BUS/RAIL prefixes.

#### Code before — my current implementation

The trip ID normalization in both transformations is numeric-only and pads to seven digits:

```sql
CASE
    WHEN trip_id NOT GLOB '*[^0-9]*'
     AND trip_id <> ''
     AND length(ltrim(trip_id, '0')) BETWEEN 1 AND 7
    THEN printf('%07d', CAST(ltrim(trip_id, '0') AS INTEGER))
    WHEN trip_id NOT GLOB '*[^0-9]*'
     AND trip_id <> ''
     AND length(ltrim(trip_id, '0')) = 0
    THEN '0000000'
END AS trip_id
```

The vehicle expression accepts only four digits:

```sql
CASE
    WHEN length(vehicle_id) = 4
     AND vehicle_id NOT GLOB '*[^0-9]*'
    THEN CAST(vehicle_id AS TEXT)
END AS vehicle_id
```

The history cleaning stage trims surrounding whitespace, but `transform_trip` and `transform_update` do not remove the spreadsheet suffix `.0` before the numeric-only test. The exact seven-character padding also changes the identifier representation; the target contract asks for the timetable's trip ID as text, not a numeric value formatted to a fixed width.

#### Reference behavior

The reference strips spreadsheet quoting and a terminal decimal suffix only when the fractional part consists entirely of zeros. It trims fixed-width whitespace. For vehicle IDs, it accepts digit-only values and strips recognized BUS/RAIL prefixes while preserving the remaining digits.

#### Code after — proposed change

Use the same normalization expression on both trip sources. Do not cast an identifier to an integer merely to normalize it; that can destroy leading zeros:

```sql
WITH id_text AS (
    SELECT trim(trip_id) AS trip_id_text
    FROM source_rows
),
id_normalized AS (
    SELECT CASE
        WHEN trip_id_text GLOB '*.[0]*'
         AND substr(trip_id_text, 1, instr(trip_id_text, '.') - 1)
             NOT GLOB '*[^0-9]*'
         AND substr(trip_id_text, instr(trip_id_text, '.') + 1)
             NOT GLOB '*[^0]*'
        THEN substr(trip_id_text, 1, instr(trip_id_text, '.') - 1)
        ELSE trip_id_text
    END AS trip_id
    FROM id_text
)
SELECT trip_id FROM id_normalized;
```

Apply it consistently to `trips` and `trip_updates`. If the contract requires canonical removal of leading zeros, do that as a separately documented business rule; do not add seven-character zero-padding unless the source contract explicitly requires it.

Vehicle normalization should be separate:

```sql
CASE
    WHEN trim(vehicle_id) GLOB '[0-9]*'
     AND trim(vehicle_id) NOT GLOB '*[^0-9]*'
    THEN trim(vehicle_id)
    WHEN upper(trim(vehicle_id)) GLOB 'BUS[- :_]*'
      OR upper(trim(vehicle_id)) GLOB 'RAIL[- :_]*'
    THEN CASE
        WHEN ltrim(trim(vehicle_id), 'BUSRAIL -:_') <> ''
         AND ltrim(trim(vehicle_id), 'BUSRAIL -:_') NOT GLOB '*[^0-9]*'
        THEN ltrim(trim(vehicle_id), 'BUSRAIL -:_')
    END
END AS vehicle_id
```

For production use, make the prefix removal explicit and test it carefully: SQLite's `ltrim(X,Y)` removes any characters in Y, not the literal prefix token. A safer version checks the prefix first, removes exactly the prefix plus separator, and then validates digits. Preserve leading zeros.

**Worked example:** `7041203.0` should normalize to `7041203`; `" 7041203 "` should normalize to `7041203`; `BUS-002594` should normalize to `002594`, not `2594`.

**Why it matters:** A join key that differs by a decimal suffix or whitespace does not match the timetable. A vehicle parser that rejects a valid prefixed number makes the first-start vehicle NULL.

### Finding 6 — Event vocabulary and cancellation precedence need a deliberate rule

**Evidence:** `dag.sql`, event-type CASE and `norm_status` (around lines 245–276). README says the suppliers use values such as DEPARTED/departure, ARRIVED/arrival, and CANCELLED/canceled; it also describes a trip withdrawn and then operated.

#### Code before — my current implementation

```sql
CASE
    WHEN lower(event_type) IN
         ('start','started','begin','began','departure','depart','commence')
    THEN 'start'
    WHEN lower(event_type) IN
         ('end','ended','finish','finished','complete','completed','arrival','arrive')
    THEN 'end'
    WHEN lower(event_type) IN
         ('cancel','cancelled','canceled','abort','aborted','void','stop','stopped')
    THEN 'cancel'
END AS event_type
```

```sql
CASE
    WHEN schedule_relationship = 'CANCELED'
         OR event_type = 'cancel'
    THEN 'cancelled'
    WHEN event_type = 'start' THEN 'started'
    WHEN event_type = 'end'   THEN 'completed'
END AS normalized_status
```

The vocabulary covers several variants, but it omits the explicit `departed` and `arrived` forms documented in the reference. Also, the relationship check wins even when the event itself says start or end.

#### Reference behavior

The reference maps the supplier event vocabulary into `start`, `end`, or `cancel`, including `departed` and `arrived`. It uses a canceled relationship as a fallback when the event type itself does not identify the event. The final status is then chosen from the latest event, with a deterministic load/event tie-break.

#### Code after — proposed change

```sql
CASE
    WHEN lower(trim(event_type)) IN
         ('start','started','depart','departure','departed',
          'departed_origin','trip_start','trip started','trip_started',
          'begin','began')
    THEN 'start'
    WHEN lower(trim(event_type)) IN
         ('end','ended','finish','finished','complete','completed',
          'arrival','arrive','arrived','trip_end','trip_completed','stop')
    THEN 'end'
    WHEN lower(trim(event_type)) IN
         ('cancel','canceled','cancelled','cancellation',
          'cancelled_trip','trip_cancelled','trip_canceled','cancel_trip')
    THEN 'cancel'
    WHEN upper(trim(schedule_relationship)) IN ('CANCELED','CANCELLED')
    THEN 'cancel'
END AS event_kind
```

Then normalize the event state from `event_kind`:

```sql
CASE event_kind
    WHEN 'cancel' THEN 'cancelled'
    WHEN 'start'  THEN 'started'
    WHEN 'end'    THEN 'completed'
END AS normalized_status
```

Retain the latest-event ranking, but add a stable final tie-breaker such as `event_key` after event time and load time. The event type should describe what the vehicle reported; the relationship should only fill in an otherwise unknown event kind.

**Edge cases:** cancellation followed by a real start, duplicate event times, NULL event time, and reports arriving out of order. A later-arriving correction can have an older event timestamp, so decide whether the task's “last reported state” is ordered by event time, load time, or a documented combination. The reference's final aggregation orders by event time and load ordinal.

### Finding 7 — The output should be restricted to the task's service-date window

**Evidence:** README target range is 2026-10-02 through 2026-10-31. Your `trip_actuals` begins with:

```sql
WITH keys AS (
    SELECT DISTINCT trip_id, service_day
    FROM transform_update
),
```

The final SELECT reads all `final_rows` without a date predicate. The reference filters `resolved_events` to the required range before grouping.

#### Code after — proposed change

```sql
WITH keys AS (
    SELECT DISTINCT trip_id, service_day
    FROM transform_update
    WHERE service_day BETWEEN '2026-10-02' AND '2026-10-31'
),
...
```

Also keep the same filter in the final reconciliation layer if the runner can materialize historical rows from earlier runs. This is a correctness boundary, not merely a display filter.

**Caution:** The README says raw tables retain only five nights of updates and seven nights of timetable data, while the history tables are intended to carry data forward. Do not delete history outside the target range if it is needed to resolve late-arriving reports or timetable versions. Filter the output, not the retained evidence needed to build it.

### Finding 8 — The DAG is missing explicit feed readiness and the resolution stages

**Evidence:** Your DAG header (lines 1–21) declares a nightly schedule and five tasks. The reference header declares a sensor, merge-based history tasks, timetable version/entry views, event resolution, and final aggregation.

#### Code before — my current DAG configuration

```yaml
dag: the_timetable
schedule: nightly           # 13:00 UTC
tasks:
  trip_updates_history:
    materialized: incremental
    unique_key: trip_update_key
    depends_on: [trip_updates]
  trips_history:
    materialized: incremental
    unique_key: trip_key
    depends_on: [trips]
  transform_trip:
    materialized: table
    depends_on: [trips_history]
  transform_update:
    materialized: table
    depends_on: [trip_updates_history]
  trip_actuals:
    materialized: table
    depends_on: [transform_update, transform_trip]
```

#### Reference structure

The reference's DAG header includes:

- `rail_ready`: sensor with a 12-hour timeout and soft-fail behavior.
- `trip_updates_history`: incremental merge on `event_key`, dependent on `rail_ready`.
- `trips_history`: incremental merge on `file_key, trip_id`, dependent on `rail_ready`.
- `timetable_versions` and `timetable_entries`.
- `resolved_events`.
- `trip_actuals`.

#### Code after — proposed DAG structure

Use this as the intended dependency structure, then adapt the sensor syntax and schedule to the actual runner's contract:

```yaml
dag: the_timetable
schedule: nightly
tasks:
  rail_ready:
    materialized: sensor
    depends_on: [trip_updates]
    schedule: "0 13 * * *"
    timeout: 12h
    soft_fail: true

  trip_updates_history:
    materialized: incremental
    depends_on: [trip_updates, rail_ready]
    incremental_strategy: merge
    unique_key: [event_key]
    trigger_rule: none_failed

  trips_history:
    materialized: incremental
    depends_on: [trips, rail_ready]
    incremental_strategy: merge
    unique_key: [file_key, trip_id]
    trigger_rule: none_failed

  timetable_versions:
    materialized: view
    depends_on: [trips_history]

  timetable_entries:
    materialized: view
    depends_on: [timetable_versions, trips_history]

  resolved_events:
    materialized: view
    depends_on: [trip_updates_history, timetable_entries]

  trip_actuals:
    materialized: view
    depends_on: [resolved_events]
```

**Important scheduling qualification:** The challenge DOC says the run is nightly at 13:00 UTC for 30 nights, while the reference DAG declares `0 1,7,13,19 * * *` plus a separately scheduled sensor. Do not blindly copy both schedules. Preserve the challenge runner's actual expected cadence; use the sensor/readiness behavior only in a way supported by the runner. The missing dependency is a plausible late-feed risk, not proof of a runtime failure.

## 4. What is already good and should be preserved

- The output is assembled at the intended trip/day grain using `keys` and window functions.
- The final query returns the nine target columns in the required order.
- The code uses the timetable's latest version by effective day and load time within each `(trip_id, service_id, effective_day)` partition.
- The feed route is used when no timetable row is available, which is necessary for extra trips.
- The earliest start is selected separately from the latest status. This is important because the first vehicle to start the trip is not necessarily the vehicle on the latest event.
- Negative delay should remain negative: the README explicitly says leaving early is a fault, not zero delay or absolute delay.
- Do not remove event history merely to simplify aggregation. Late end events, amended reports, and reports split across files require revisiting earlier trip-day results.

## 5. Validation plan

### Actually inspected / executed

- Read the reusable review skill.
- Read `README.md`, `dag.sql`, `gold_submit.sql`, and `week-7_DOC.md`.
- Compared the submitted DAG task configuration and SQL CTEs with the reference DAG and SQL.
- Checked the exact case-sensitive paths for `GPT_Analysis.md` and `GPT_analysis.md`; neither existed at review time.
- Read the already-created PostgreSQL companion header and inspected it statically.
- **No SQLite challenge execution, PostgreSQL execution, sample-output comparison, benchmark, or query-plan inspection was performed.**

### Proposed tests — not yet executed

| Test / query | Expected validation |
|---|---|
| Duplicate raw poll | Same `update_id` and identical content produces one history event |
| Amended report ID | Same stable `update_id` with changed fields resolves to the latest loaded version |
| Missing service date after midnight | Match the correct prior service day using timetable departure proximity |
| GTFS departure `7:05:00` | Parse as 07:05:00, not a malformed fixed-position value |
| Departure `07:05` | Parse with seconds defaulted to zero |
| Departure `25:10:00` | Schedule is 01:10 on the next UTC calendar date but retains the previous service date |
| ISO timestamp with `Z` | Convert to the same UTC epoch |
| ISO timestamp with `-07:00` | Respect the explicit offset; do not add the agency offset a second time |
| Local ISO timestamp without offset | Apply the documented agency offset exactly once |
| Spreadsheet trip ID `7041203.0` | Normalize to `7041203` and match timetable row |
| Fixed-width trip ID with blanks | Trim and match without changing the identifier unexpectedly |
| Vehicle `BUS-002594` | Normalize to `002594`, preserving leading zeros |
| End event with no vehicle | Keep the vehicle from the earliest valid start |
| Relief vehicle starts later | Keep the first-start vehicle, not the later relief vehicle |
| Cancelled then operated | Latest valid event state is reflected |
| Trip moved to another route | Use route from timetable version effective on service day |
| Amended timetable file | Use later publication for the same effective date |
| Extra trip absent from timetable | Keep one output row, feed route, NULL scheduled start/delay, `unscheduled = 1` |
| Cross-midnight trip across two files | Reconcile start and end into one trip-day row |
| Early departure | Preserve negative `delay_s` |
| Output grain | No duplicate `(trip_id, service_date)` |
| Date boundary | Output contains only 2026-10-02 through 2026-10-31 |
| NULL reconciliation | Missing source values remain NULL where the contract requires NULL |

Suggested duplicate-key check after materialization:

```sql
SELECT trip_id, service_date, COUNT(*) AS row_count
FROM trip_actuals
GROUP BY trip_id, service_date
HAVING COUNT(*) > 1;
```

Suggested output-window and NULL checks:

```sql
SELECT
    COUNT(*) AS rows_total,
    SUM(CASE WHEN trip_id IS NULL THEN 1 ELSE 0 END) AS null_trip_id,
    SUM(CASE WHEN service_date IS NULL THEN 1 ELSE 0 END) AS null_service_date,
    SUM(CASE WHEN unscheduled NOT IN (0, 1) OR unscheduled IS NULL
             THEN 1 ELSE 0 END) AS invalid_unscheduled,
    SUM(CASE WHEN delay_s IS NOT NULL
                  AND (actual_start IS NULL OR scheduled_start IS NULL)
             THEN 1 ELSE 0 END) AS invalid_delay
FROM trip_actuals
WHERE service_date BETWEEN '2026-10-02' AND '2026-10-31';
```

Suggested key reconciliation against the target/expected fixture:

```sql
-- Replace expected_trip_actuals with the challenge's expected fixture table.
SELECT e.trip_id, e.service_date
FROM expected_trip_actuals e
LEFT JOIN trip_actuals a
  ON a.trip_id = e.trip_id
 AND a.service_date = e.service_date
WHERE a.trip_id IS NULL;

SELECT a.trip_id, a.service_date
FROM trip_actuals a
LEFT JOIN expected_trip_actuals e
  ON e.trip_id = a.trip_id
 AND e.service_date = a.service_date
WHERE e.trip_id IS NULL;
```

Compare all nine columns, not just row counts. A matching key does not guarantee correct timestamps, status, vehicle, route, or delay.

## 6. Reusable lessons

1. **Do not infer business dates from file dates when the event has its own time semantics.** File date, load time, event time, and service date are four different concepts.
2. **Normalize timestamps and clocks once.** Convert raw strings to typed epochs/seconds early, then use those values consistently in ordering, matching, and arithmetic.
3. **Keep stable identity separate from mutable attributes.** A report ID is a better event identity than a concatenation of every field that may later be corrected.
4. **Incremental does not automatically mean correct.** A pipeline needs idempotency, merge semantics, late-arrival handling, and a clear history-retention policy.
5. **Resolve facts before aggregating.** Determine the event's service day and applicable timetable version before collapsing events into a trip-day result.
6. **Do not discard information needed by later events.** The first start determines the vehicle and actual departure; the latest event determines status; a later end can revise a trip already seen in an earlier run.
7. **Test the contract's adversarial cases explicitly.** One happy-path sample will not expose offset timestamps, 25-hour service times, amended reports, missing service days, or relief vehicles.

## 7. Evidence boundaries and remaining uncertainty

**Repository facts:** Score/rank, row counts, column-level feedback, condition recovery, target schema, date range, source table retention, and the agency UTC offset are documented in the README and `week-7_DOC.md`. Code behavior described as “current” is taken from `dag.sql`. Reference behavior is taken from `gold_submit.sql`.

**Hypotheses:** The impact ranking estimates which defects are likely to explain the weak output columns. The README does not provide a per-defect causal attribution, and no evaluator logs identify a failed task. The exact contribution of each issue therefore remains unmeasured.

**Not established:** No query was executed during this review. No test result, runtime failure, query plan, or performance improvement is claimed. The README's 1.0× median work per raw row is the only reported performance measure.

**Target path:** `weekly/week-07-the-timetable/GPT_Analysis.md`
