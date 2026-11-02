# Week 7 — The Timetable: Challenge Overview

## 1. Problem statement and output contract

A city bus and light-rail agency receives two views of service:

- **trip_updates** is an event log. Vehicles report trip starts, ends, and cancellations. The log is split into daily files and may contain repeated, delayed, amended, or incomplete reports.
- **trips** is the published timetable. Each export is a full schedule version, with a start date indicating when that version becomes effective.

Build a nightly SQL DAG that reconciles those sources into **one row per (trip_id, service_date)** for service dates **2026-10-02 through 2026-10-31**. The target is trip_actuals, with these nine columns:

| Column | Meaning |
|---|---|
| trip_id | Trip identifier as text; feed identifier for an extra trip |
| service_date | Service day in YYYY-MM-DD |
| route_id | Route from the timetable, or from the feed for an unscheduled trip |
| scheduled_start | Scheduled first departure, expressed as a UTC ISO timestamp |
| actual_start | Earliest valid vehicle start, in UTC; NULL if none |
| delay_s | Actual minus scheduled start, in whole seconds; may be negative |
| status | Last reported state: completed, started, or cancelled |
| vehicle_id | Digits-only fleet identifier for the vehicle that first started the trip |
| unscheduled | 1 when no timetable entry applies to that trip on that service day; otherwise 0 |

The target grain is not one row per raw report, file, or timetable version. It is one row per trip on its service day. Trips with no start, end, or cancellation event are excluded. The contract and sample target are documented in week-7_DOC.md; the README describes the operational traps.

**Important contract details:** The agency clock is UTC−7. Timetable times beyond 24:00 belong to the preceding service day (for example, 26:04 is 02:04 on the following calendar date but remains part of the prior service day). A timetable version applies from its effective date until the next version takes effect. A trip with no matching timetable entry is still represented when the feed reports it, but it has no scheduled departure to compare against.

## 2. Domain context

**Domains involved**

1. **Public-transit operations and GTFS / GTFS-Realtime concepts.** A scheduled trip is a planned piece of service; real-time updates describe what a vehicle actually did. A service day is a timetable concept and is not always the same as the calendar date on which an event timestamp falls.
2. **Event-data processing.** Starts, ends, and cancellations are separate facts about a trip. They can arrive out of order, more than once, or in different daily files.
3. **Slowly changing reference data.** Timetable exports are full snapshots with effective dates. The correct schedule is the version valid on the trip's service date—not automatically the newest file or the first file seen.
4. **SQL-based orchestration and incremental ELT.** The solution must retain useful history, coordinate dependencies, and rebuild a stable analytical table as new files arrive.

Useful background: UTC versus local time, epoch seconds versus milliseconds, event logs versus snapshots, primary keys and grain, window functions, incremental materializations, and effective-dated dimensions.

## 3. Difficulty assessment

**Difficulty: 5 / 5 — Very challenging**

- **Conceptual complexity — very high:** two source systems describe the same service from different perspectives, and neither source alone is sufficient. The solution must infer service-day identity, select the effective schedule version, and derive trip-level facts from event-level records.
- **Edge-case density — very high:** the README enumerates many independent conditions: duplicate reports, multiple event vocabularies, NULL sentinels, missing dates, multiple timestamp encodings, late exports, delayed events, relief vehicles, cancellations, extra trips, and amended schedule files.
- **Correctness sensitivity — very high:** a wrong key, service day, timestamp, event ordering, or schedule version can affect several output columns. The grain and NULL semantics are explicit.
- **Performance and memory — high:** the reference design retains history and uses multiple normalization and reconciliation stages. The task document specifies a 512 MB memory budget and a 10-minute runtime cap, so unbounded raw-history scans and unnecessary row multiplication matter.
- **Operational complexity — high:** the DAG runs nightly, while source files can be delayed, re-exported, or delivered out of order. A correct design must account for retries, reruns, incremental state, and readiness of both feeds.

The rating describes the challenge contract and its engineering demands; it is not an assessment of any particular execution.

## 4. Main traps and hidden requirements

The README and task document describe the following conditions. Treat them as independent test dimensions rather than assuming one generic cleanup step will solve them.

### Source cleanliness and key normalization

- NULL-like values arrive as ordinary text, with different spellings and whitespace.
- Trip identifiers can contain surrounding blanks or a spreadsheet-added .0.
- Vehicle identifiers can contain leading zeroes, blanks, or BUS / RAIL prefixes.
- The same logical date can appear as YYYYMMDD or YYYY-MM-DD; string comparison alone is unsafe.
- Two suppliers use different event vocabularies for start, end, and cancellation.
- Duplicate polls can write the same report more than once, including with the same report ID and timestamp.

**Trap:** cleaning a column for display is not enough. Normalize identifiers and dates before joining, deduplicating, or partitioning. Keep raw values or provenance where useful for diagnosis.

### Time and service-day interpretation

- Event time may be epoch seconds, epoch milliseconds, or ISO text with timezone information.
- Bus and rail feeds do not necessarily use the same timestamp unit or serialization.
- A vehicle may report a placeholder clock such as 1970 or 1980 before its clock is synchronized.
- A scheduled departure can use one-digit hours, omit seconds, or exceed 24 hours.
- Some events omit the declared service day. For those, the likely service day must be inferred from timetable departures near the event—not simply copied from the file date.
- A trip crossing midnight can have its start and end in different daily files.
- A departure before schedule is an early departure and must produce a negative delay, not zero or an absolute difference.

**Trap:** timestamp parsing and service-day assignment are separate problems. First normalize the instant; then reason about which service day and schedule entry that instant belongs to.

### Versioning, late data, and event semantics

- A new timetable may be published before its effective date.
- A later publication can amend an earlier file for the same effective date; the later publication is authoritative.
- A trip can be moved to a different route in a new schedule version. A cached route in the real-time feed may be stale.
- An export may start late, so the data can be observed by a later DAG run under an earlier batch date.
- Rail rows can arrive after the run has already advanced its watermark.
- A disconnected unit may upload an end event days after its start.
- A relief vehicle can report another start for a trip that already started; the first vehicle remains the vehicle associated with the trip's first start.
- A cancellation may later be withdrawn in practice when a vehicle actually operates the trip. The final reported state must reflect event ordering.
- An extra trip has no timetable row; its route comes from the feed and its scheduled time is NULL.

**Trap:** batch_id, loaded_at, event time, timetable effective date, and service date represent different clocks. Do not substitute one for another.

## 5. Heuristic experience-equivalent estimates

These ranges are rough skill-equivalence estimates, not claims about anyone's actual employment history. They are not reliable hiring-level verdicts. They estimate the kind of experience that would typically make someone comfortable designing and reviewing work of this shape. They are distinct from the challenge's 5/5 difficulty rating.

| Artifact being assessed | Heuristic range | Why |
|---|---:|---|
| Problem described in README | **3–6 years** of relevant data-engineering experience | The requirements combine event reconciliation, effective-dated reference data, messy source formats, and late-arriving data. A capable engineer could implement parts earlier, but designing a coherent end-to-end contract usually benefits from production pipeline experience. |
| User submission: dag.sql | **2–4 years** equivalent | The five-task design shows practical SQL pipeline experience: incremental history tables, normalization stages, window-based deduplication, event ranking, schedule-version selection, and a final trip-grain output. The implementation is more than a beginner query, but its normalization and temporal-reconciliation coverage is narrower than the complete problem contract. |
| Reference solution: gold_submit.sql | **5–8 years** equivalent | The reference separates durable history, readiness gating, timetable-version selection, event-to-service-day resolution, and final aggregation. It handles more timestamp encodings and late-arrival patterns, and uses a more explicit event identity and file/version model. This is closer to the design breadth expected of an experienced analytics / data-platform engineer. |

**Rubric:** the estimate considers (1) data-model and domain reasoning, (2) breadth of edge-case handling, (3) temporal and event semantics, (4) incremental-state and orchestration design, and (5) maintainability and explicitness of the contract. It does **not** use code length as a proxy for skill, and it does not infer the author's real years of employment.

For the submitted code, this is an assessment of implementation scope and design maturity only. It is not an execution report.

## 6. User submission versus reference approach

### What the submission does well

The user's dag.sql has a clear five-stage structure:

1. trip_updates_history and trips_history establish incremental history and deduplicate source rows using composite keys.
2. transform_trip standardizes trip IDs, service labels, departure strings, and timetable effective dates.
3. transform_update standardizes trip IDs, event IDs, service dates, vehicle IDs, event vocabulary, relationship values, and numeric epoch timestamps.
4. trip_actuals derives trip-level status, first start, feed route, applicable schedule, delay, and the unscheduled flag.

The final query uses window functions to select the latest status, earliest valid start, and a route candidate. The schedule join selects an effective date no later than the service day and checks the weekday/weekend service class. This is a sensible decomposition and demonstrates awareness of output grain, deduplication, event ordering, and effective-dated schedule selection.

### Most important differences

| Concern | User submission | Reference solution |
|---|---|---|
| DAG architecture | Five tasks: two histories, two transforms, one final table | Seven tasks: two histories, a rail-readiness sensor, timetable-version and entry views, resolved events, and final table |
| Incremental history | Builds a composite key and inserts keys not already present | Uses normalized event/file identities and merges existing history for keys being refreshed, allowing newer representations of an existing logical record to be considered |
| Event timestamp parsing | Converts 10-digit seconds and 13-digit milliseconds | Parses numeric forms and ISO timestamp text, including timezone offsets, into a normalized event instant |
| Timetable clock parsing | Accepts strict HH:MM:SS strings | Handles additional clock representations, including shortened clocks and spreadsheet-style numeric time values |
| Timetable version model | Ranks a schedule row by trip/service/effective date and chooses the latest effective date | Identifies timetable files, selects the authoritative publication for each effective date, and represents validity as an interval ending at the next version |
| Missing service day | Falls back to the batch date when the declared date cannot be parsed | Builds candidate service days around the event's local calendar day and matches against timetable departures |
| Feed readiness | No separate readiness task in the submitted DAG | Includes a rail readiness sensor so the downstream model can wait for relevant feed data |
| Trip-level resolution | Groups primarily by normalized trip ID and service day inferred in the transform | Resolves individual events against effective timetable entries before aggregating to trip grain |
| Event and vehicle selection | Chooses earliest qualifying start and latest event status using event/load ordering | Carries event identity, event ordering, and first-start vehicle through the resolution stage, then derives the final state from the selected last event |

### What the reference handles that the submission does not fully cover

The most consequential gaps are broader timestamp parsing, richer timetable-clock parsing, missing-service-day inference, explicit timetable file/version intervals, and a feed-readiness dependency. The reference also treats a late or amended record as a reason to reconsider affected history rather than relying only on whether a composite key has ever been inserted.

The submission's service-day fallback (parsed start_date or batch_id) is a practical baseline, but the README specifically describes reports whose declared service day is absent and whose batch date is not the service day. Likewise, accepting only numeric epoch seconds/milliseconds does not cover ISO text timestamps.

### Do not copy every reference detail blindly

The reference is a useful implementation example, not proof that every CTE or implementation trick is mandatory. A different robust design could use a normalized staging table, an explicit timetable-version dimension, and a merge/upsert strategy with equivalent semantics. The essential requirement is to preserve the contract: correct event identity, service day, schedule version, event ordering, and one output row per trip/service day.

## 7. Technical concepts worth studying

1. **GTFS service-day semantics and times beyond 24:00.** Learn why a timetable's service day differs from a calendar date and how to convert extended-hour departures into real timestamps.
2. **Timestamp normalization.** Parse epoch seconds, epoch milliseconds, ISO-8601 timestamps, offsets, and invalid clock placeholders into one well-defined representation. Keep timezone conversion explicit.
3. **Effective-dated dimensions / SCD Type 2.** Model each timetable version with an effective start and exclusive end date. Select the version valid for the service day, including re-published versions for the same start date.
4. **Event sourcing and state reconstruction.** Understand why start, end, cancellation, and later-arriving events should be treated as an ordered event history rather than as independent rows.
5. **Window functions.** Practice ROW_NUMBER, FIRST_VALUE, LAST_VALUE, MIN / MAX over partitions, and deterministic tie-breaking for first-start and last-state logic.
6. **Deduplication and idempotent ingestion.** Distinguish duplicate delivery from a corrected record. A stable natural/event key plus a clear update policy is safer than blindly dropping every key seen before.
7. **Incremental models and late-arriving data.** Compare append-only watermarks, lookback windows, merge-based models, and targeted reprocessing. Understand why a late event can change an already-built trip row.
8. **Join cardinality and output grain.** Verify that each event matches at most the intended timetable version and that aggregation returns one row per trip/service date. Watch for many-to-many joins.
9. **NULL and sentinel normalization.** Convert textual NULL markers before key construction and joins; preserve genuine unknowns as SQL NULL rather than strings.
10. **SQLite / DAG templating constraints.** The submitted and reference SQL use SQLite-style functions and templated DAG directives such as is_incremental(), {{ this }}, and {{ ts }}. Understand the engine's supported functions and how task materialization affects SQL semantics.

## 8. Additional engineering learning angles

### Data model and grain

Draw the entities before writing SQL:

- Raw update: one report about one trip event.
- Timetable file: one published full snapshot with a publication timestamp and effective date.
- Timetable entry: one trip's planned departure within a specific version.
- Resolved event: one normalized report assigned to a candidate trip and service day.
- Trip actual: one aggregate row per (trip_id, service_date).

Ask whether every intermediate table has a documented key and whether a join can multiply rows. The final grain should be enforced deliberately, not achieved accidentally with DISTINCT.

### Assumptions to make explicit

- Which timestamp is the event instant, and which timestamp records when the pipeline learned about it?
- How are conflicting reports ordered when event timestamps tie or are missing?
- Which timetable publication wins when multiple files have the same effective date?
- How is a missing service day inferred, and what confidence boundary prevents matching an event to an unrelated departure?
- What identifies an extra trip when it has no schedule row?
- Does a cancellation remain the final state if a later start/end report arrives?

### Correctness versus performance

A broad history scan can be easier to reason about but expensive. A narrow watermark is efficient but can permanently miss late rows. A bounded lookback is a compromise only when the maximum lateness is known and enforced. Merge-based processing can revisit affected keys, but requires stable identities and careful update semantics.

Materializing intermediate normalized data can make logic testable and reduce repeated parsing, at the cost of storage and extra DAG tasks. Window functions simplify deterministic selection, but their partitions and sort keys should be as small and selective as the data model allows.

### Operational reliability and observability

In a production pipeline, expose source batch dates, load timestamps, feed names, normalization outcomes, and the selected timetable version as lineage columns or audit metadata. Useful generic signals include source freshness, late-arrival counts, duplicate rates, unmatched timetable keys, invalid timestamp counts, and the age of the newest processed event.

Retries should be safe: rerunning a batch must not create duplicate trip rows or discard a corrected event. Late data should have an explicit reprocessing policy. A readiness sensor should have a timeout and a clear failure/skip policy so a missing feed does not silently create incomplete downstream output.

### Test strategy

Use small, contract-focused fixtures before testing at full scale. Test each normalization function independently, then test event-to-schedule resolution, and finally test the complete DAG. Recommended tests are proposed below; they are not claims that these tests have been executed.

## 9. Suggested learning plan and validation checklist

### Priority 1 — Understand the clocks and keys

- [ ] Write down the difference between service_date, event time, batch_id, loaded_at, timetable effective date, and publication time.
- [ ] Normalize YYYYMMDD and YYYY-MM-DD to the same date value.
- [ ] Test trip IDs with leading/trailing spaces, leading zeroes, and a spreadsheet suffix such as .0.
- [ ] Test NULL sentinels such as NULL, \N, empty text, and whitespace.
- [ ] Confirm that two deliveries of the same report do not create two logical events, while a genuine correction can replace or supersede an earlier representation.

### Priority 2 — Make time handling reliable

- [ ] Parse epoch seconds, epoch milliseconds, and ISO-8601 text with Z and explicit offsets.
- [ ] Reject or quarantine placeholder device-clock timestamps rather than calculating a multi-decade delay.
- [ ] Parse 7:05, 07:05, 07:05:00, and an extended-hour value such as 26:04:00.
- [ ] Verify that a 26-hour timetable departure maps to 02:04 on the following calendar date while retaining the preceding service date.
- [ ] Verify the UTC−7 conversion with a known timestamp and check daylight-saving assumptions against the task's stated fixed-offset contract.

### Priority 3 — Resolve timetable versions and events

- [ ] Create two timetable versions with different effective dates and verify that a trip uses the version valid on its service day.
- [ ] Create two publications for the same effective date and verify that the later publication wins.
- [ ] Test a trip whose declared service day is NULL; verify that candidate-day matching chooses the plausible timetable departure and rejects implausible matches.
- [ ] Test a trip with no timetable match; verify that it is marked unscheduled, uses the feed route, and has NULL scheduled time and delay.
- [ ] Test a cancellation with no vehicle start, then a cancellation followed by a real start/end sequence; verify the final state follows the defined event ordering.
- [ ] Test a relief-vehicle second start; verify that the first valid start and its vehicle are retained.
- [ ] Test a trip whose start and end are in different daily files and an end event delivered several days late.

### Priority 4 — Validate the final model and DAG

- [ ] Assert that the output has exactly the nine documented columns and the required data types / serialized formats.
- [ ] Assert uniqueness of (trip_id, service_date) and non-NULL values for both key columns.
- [ ] Recompute delay_s independently as actual minus scheduled epoch seconds; include a negative-delay case.
- [ ] Verify that status is only completed, started, cancelled, or NULL according to the contract.
- [ ] Verify that vehicle_id comes from the first valid start, not the last event or the last vehicle.
- [ ] Simulate a late source file and a rerun; confirm the affected trip is revised without duplicate output.
- [ ] Inspect DAG dependencies and readiness behavior so the final model cannot run against an incomplete required feed.
- [ ] Review query plans and intermediate row counts on representative data; check that joins do not unexpectedly multiply records and that memory use is bounded.

## 10. Evidence, interpretation, and uncertainty

**Facts stated by the task materials:** the two raw source tables and their documented columns; the target's nine-column contract and composite grain; the service-day, timezone, timetable-version, and late-data rules; the daily file retention windows; the stated memory/runtime limits; and the listed edge cases. These are taken from README.md and week-7_DOC.md.

**Facts visible in code:** the user's dag.sql defines five tasks and uses incremental history tables, normalization transforms, window-based event selection, and a final schedule join. The reference gold_submit.sql defines seven tasks, including a rail-readiness sensor, timetable-version and entry stages, event resolution, and final trip aggregation. The comparisons above describe the visible SQL structure and logic.

**Interpretations:** the difficulty rating, experience-equivalent ranges, and judgments about relative design maturity are reasoned estimates based on the contract and code. They are not employment-history claims or validated hiring assessments.

**Uncertainty:** this overview does not claim to have executed the SQL, benchmarked it, or independently validated every edge case. Any test in the checklist is a recommendation until actually run. Execution outcomes and evaluator feedback belong in GPT_Analysis.md, not in this conceptual guide.
