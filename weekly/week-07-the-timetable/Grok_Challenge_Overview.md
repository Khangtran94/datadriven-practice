# Week 7 – The Timetable: Challenge Overview

## 1. One-sentence verdict
This is a hard production-style incremental + as-of timetable matching challenge for a data engineer with roughly 3–5 years of experience in transit / real-time operations data platforms.

## 2. Domain & context
- **Simulated business**: a city bus and light-rail agency.
- **Pipeline goal**: produce one clean row per trip (service_date, trip_id) for the window 2026-10-02 → 2026-10-31, with scheduled_start, actual_start, delay_s, status, vehicle_id, route_id and an unscheduled flag.
- **Raw inputs**: two nightly copy tables (`trip_updates` — every start/end/cancel report; `trips` — weekly timetable versions with first_departure). Files can be late, duplicated, partially rewritten, or missing service_date. The landing zone does not retain history forever, so the DAG must be incremental and correct under incomplete visibility.

## 3. Core data-engineering problems
The README deliberately injects the following production realities (ordered roughly by frequency/impact):

1. **Times in three forms** — HH:MM:SS, HH:MM, and 1-digit hours; fixed-position reads fail.
2. **Start dates with dashes** — 2026-10-23 vs 20261023; text comparison mis-orders versions.
3. **Event times as millis, seconds or ISO text** (sometimes with local offset) — last-report and first-start ranking fail when sorted as text.
4. **Start / end / cancel vocabulary** — DEPARTED vs departure, ARRIVED vs arrival, CANCELLED vs canceled.
5. **Unplanned extra trips** — feed reports a trip with no timetable row; route comes from the feed, scheduled_start is null, unscheduled = 1.
6. **End rows missing fleet number** — vehicle must be taken from the first valid start, not the newest row.
7. **Service day omitted on rail after midnight** — must be inferred from the nearest timetable departure.
8. **Trips past 24:00:00** — GTFS service day continues past midnight; reports land in the next calendar file.
9. **Fleet numbers with prefixes / leading zeros / blanks** — BUS1234, RAIL 0567, etc. must collapse to the same id.
10. **Timetable versions, late files, and re-exports** — effective_day, feed_version, and as-of selection decide the scheduled time.

The scoring harness penalises both missing rows and wrong values on the nine output columns.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Incremental history + stable event / file key | Same report or timetable row can arrive in multiple files or batches. |
| Tolerant parsing (null-as-text, Excel `.0`, quoted strings, prefixes) | IDs, dates and vehicle numbers arrive in many dirty forms. |
| Multi-form timestamp normalisation | Seconds, milliseconds, ISO-8601 with/without offset, Excel serial dates. |
| As-of timetable join | The version in force on the service day (not the newest file) supplies scheduled_start and route. |
| Service-day inference | Missing start_date on post-midnight rail reports must be resolved against the timetable. |
| First-start / last-event collapse | Vehicle and status come from specific events, not the absolute latest row. |
| Unscheduled / extra-trip handling | Feed-only trips must still appear with unscheduled = 1. |
| DAG sensors & look-back | Rail file can arrive after the morning watermark; a sensor or full-window merge is required. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3–4 years | Dozens of realistic dirty-data, late-data and as-of conditions across two feeds; requires incremental design, timetable versioning and defensive parsing. |
| Your submission (`dag.sql`) | Mid | ~2 years | Solid incremental skeletons and basic cleaning, but limited time/date/vehicle normalisation, no service-day inference, and weaker as-of / first-start logic. |
| Reference solution (`gold_submit.sql`) | Senior+ | 5+ years | Full production defensive style: multi-form parsers, sensor for rail, as-of timetable entries, nearest-day inference, packed last-non-null style ranking, and correct unscheduled handling. |

## 6. Skill map

**Primary skills trained**
- Designing incremental history tables with a correct unique key
- Normalising multi-form timestamps, dates and identifiers
- As-of join against a slowly-changing timetable
- Collapsing multi-event trip reports into one planner row (first start, last status, vehicle from start)

**Secondary skills**
- Service-day inference when the report omits the date
- Handling unscheduled extra trips and trips that cross midnight
- DAG sensors / look-back for late rail files

**Can be deferred on a first pass**
- Perfect recovery of every exotic Excel quote or 1-digit hour spelling
- Micro-optimisations of the ranking key

## 7. Learning path
1. Strengthen the cleaning tasks so every timestamp form (seconds, millis, ISO, Excel serial) and every identifier form (`.0`, leading zeros, BUS/RAIL prefixes, dashed dates) becomes a canonical value before ranking.
2. Add an as-of timetable layer that selects the version whose effective_day is the latest one ≤ service_date, and a nearest-departure inference path for reports that lack start_date.
3. Build the final trip_actuals from first-valid-start (vehicle + actual_start) and last-event (status), correctly flagging unscheduled trips. Only then compare row counts and column accuracy against the gold numbers.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `dag.sql` does wrong, the concrete before/after SQL, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
