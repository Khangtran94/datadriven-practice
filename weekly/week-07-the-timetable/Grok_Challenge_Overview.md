# Week 7 – The Timetable: Challenge Overview

## 1. One-sentence verdict
This is a hard production-style incremental + as-of timetable challenge for a data engineer with roughly 3–5 years of experience in transit / real-time operations data platforms.

## 2. Domain & context
- **Simulated business**: a city bus and light-rail agency.
- **Pipeline goal**: produce one clean row per trip (service_date, trip_id) for the planning window 2026-10-02 → 2026-10-31, with scheduled_start, actual_start, delay_s, status, vehicle_id, route_id and an unscheduled flag.
- **Raw inputs**: two nightly copy tables (`trip_updates` and `trips`). `trip_updates` is a GTFS-RT-style log (start/end/cancel reports). `trips` is the weekly timetable export that is re-published as a new version. Both feeds can be late, duplicated, partially rewritten, or missing attributes; the landing zone does not retain history forever.

## 3. Core data-engineering problems
The README deliberately injects the following production realities (ordered roughly by frequency/impact):

1. **Service-day inference when the day is omitted** – rail units leave `start_date` blank after midnight; the day must be recovered by matching the report to the nearest timetable departure.
2. **GTFS times past 24:00:00** – a 25:10:00 departure belongs to the previous service day and must be parsed and anchored correctly.
3. **Multi-vocabulary event types and schedule_relationship** – DEPARTED/departure, ARRIVED/arrival, CANCELLED/canceled must be normalised.
4. **Unplanned extra trips** – dispatcher-added vehicles that have no timetable row; route comes from the feed and unscheduled = 1.
5. **As-of timetable version** – the version in force on the service day (not the newest file) decides scheduled_start and route.
6. **Late rail files and sensors** – rail rows can land after the morning run has already started; a sensor or lookback is required.
7. **Vehicle-id and trip-id normalisation** – leading zeros, BUS/RAIL prefixes, `.0` spreadsheet artefacts, blanks, and 10-digit vs 13-digit epochs.
8. **Last-non-null and relief-vehicle handling** – the first valid start (not the latest) supplies vehicle_id and actual_start; cancellation then later run must be resolved correctly.

The scoring harness penalises both missing rows and incorrect delay/status/vehicle values.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Incremental history + stable event/file key | Updates and timetable versions must be merged, not appended forever. |
| Service-day recovery / candidate matching | Missing start_date requires trying nearby days and picking the closest timetable match. |
| GTFS time arithmetic (>24 h) | Hours ≥ 24 must be accepted and converted to a real timestamp relative to the service day. |
| As-of join to timetable versions | effective_day ≤ service_day, next version starts later; service_id (WKD/SAT/SUN) must match. |
| Event vocabulary normalisation | Multiple spellings of start/end/cancel and SCHEDULED/ADDED/CANCELED. |
| Sensor / trigger_rule for late feeds | Rail file can arrive after the run has begun. |
| Tolerant parsing | Null-as-text, Excel serial dates, epoch seconds/ms, ISO with offset, `.0` ids, prefixed fleet numbers. |
| First-start vs last-status | Relief vehicle, early departure, and “cancelled then ran” all require careful ranking. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3–5 years | Dozens of realistic GTFS/GTFS-RT dirty-data and late-data conditions; requires incremental design, as-of timetable logic, service-day inference and defensive parsing. |
| Your submission (`dag.sql`) | Mid | ~2 years | Solid null cleaning and basic incremental + as-of schedule, but incomplete vocabulary, no >24 h support, weak vehicle-id normalisation, no service-day inference when blank, and append-only history. |
| Reference solution (`gold_submit.sql`) | Senior+ | 5+ years | Full production defensive style: sensor for rail, stable event_key, multi-candidate service-day matching, GTFS time arithmetic, last-non-null style ranking, comprehensive parsing (Excel serials, offsets, prefixes). |

## 6. Skill map

**Primary skills trained**
- Designing incremental history tables with a correct unique key that survives re-exports
- Recovering missing service days by matching reports to the timetable
- As-of joins against versioned timetable entries
- Robust normalisation of GTFS times, event vocabularies and fleet numbers

**Secondary skills**
- Sensor tasks and trigger_rule: none_failed for late feeds
- First-valid-start vs last-status ranking (relief vehicles, cancellations)
- Handling unscheduled extra trips

**Can be deferred on a first pass**
- Perfect recovery of every exotic Excel serial or offset spelling
- Micro-optimisations of the ranking key

## 7. Learning path
1. Strengthen the history tasks: stable unique key, proper merge (not append-only), and full null-as-text + id normalisation (`.0`, leading zeros, prefixes).
2. Add service-day inference for blank start_date (try candidate days and pick the closest timetable departure) and GTFS times ≥ 24:00:00.
3. Isolate timetable version selection (effective_day, service_id match) and first-valid-start ranking; then re-score delay_s, scheduled_start and vehicle_id.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `dag.sql` does wrong, the concrete before/after SQL, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
