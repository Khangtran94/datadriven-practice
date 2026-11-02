---
week: 7
folder: week-07-the-timetable
title: The Timetable
format: sql
domain: Transit / Bus and light rail - trip punctuality
difficulty: 4
yoe_problem: 5-7
yoe_you: 3-5 (medium)
yoe_gold: 6-9
confidence_you: medium
score: 0.7846
rank: 5/9
analysis: yes
---

# Week 7: The Timetable - Problem overview

SQL DAG · score 0.7846, rank #5 of 9 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A city bus and light rail agency needs **1 clean row per trip**: when it was due, when it left, how late it was, which vehicle ran it and how it ended. Each night a job copies 2 raw tables out of 2 systems: `trip_updates` (a log with a row for every start, end or cancellation a vehicle reported, 1 file per day, only the last 5 nights kept) and `trips` (the timetable with every trip's first departure, published whole as a new version about once a week, only the last 7 nights kept). You write the DAG that builds the planners' trip table for the days **2026-10-02 to 2026-10-31**. The hard part: the log is a stream of reports, not trips; the timetable changes under it; and the day a report belongs to is often missing, so it has to be worked out from the timetable.

## 2. Domain and real-world context

**Public transport - realtime feed (GTFS-RT) against a schedule (GTFS).** Service planners measure punctuality: scheduled start, actual start, delay (negative when a bus leaves early), cancellations, and trips that were added by the dispatcher. In real life this is everyday work for data engineers at transit agencies: two suppliers' units with different vocabularies and clocks, a timetable that is re-published every week with a start date in the future, spreadsheet exports that turn ids into decimals, and late or repeated exports.

## 3. Difficulty: 4/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 30 `[measured]` |
| Tasks in your DAG | 5 (2 history + 3 tables) `[measured]`; the gold uses 7 (2 history + sensor + 4 views) `[measured]` |
| Raw input tables | 2, from 2 systems `[measured]` |
| Output columns / expected rows | 9 columns; 107,965 expected rows `[measured]` (your DAG built 100,792) |
| Hard constraints | each task is 1 `SELECT`; raw tables keep only 5 and 7 nights `[measured]` |
| Hidden requirement | keep your own history of both tables, and pick the timetable version in force **on the service day** `[inferred]` |

Why 4: the history problem of weeks 5 and 6 is here, plus a time model (service day starts at 07:00 UTC, trips run past 24:00:00) and a missing-day problem that needs a join to the timetable to solve. It is not 5 because there is no money model, the rules are short, and the README lists the conditions.

## 4. Problems the data throws at you

1. **Reports, not trips.** A trip has a start, an end, maybe a cancellation, a relief bus, an end days later, rows twice (20%), and old rows re-sent in a newer file (8%). Hard because "take the newest row" loses the vehicle (end rows carry none, 21.6%) and the first start must be kept.
2. **The timetable is a versioned history.** A version is published weeks ahead of its start date (5.3%), an amended file is sent again (1.1%), a trip is retimed (17.2%) or moved to another route (1.3%). Hard because the version in force **on that day** decides the scheduled time and route, not the first or the newest file.
3. **Time in many spellings.** Departure as `7:05:00`, `07:05` or `25:10:00` (38.4%); event time as seconds, milliseconds or ISO text with an offset (18%); a unit clock set to 1970 (2.5%). Hard because text sorts wrongly and a delay of 56 years is silently wrong.
4. **The day left off the row.** 25% of tables; the rail rows after midnight. Hard because the day must be chosen from the timetable: the candidate day whose departure is nearest the report.
5. **Two vocabularies.** DEPARTED / ARRIVED / CANCELLED against start / end / cancel (14%). Hard because nobody mapped one onto the other.
6. **Keys and ids.** `.0` ids (6.6%), blank-padded ids (5%), dates with and without dashes (12% and 20.6%), fleet numbers with zeros, blanks or prefixes (14%). Hard because one trip can end up under two keys.
7. **Late arrivals.** An export runs after the morning run (23.8%), rail rows after it (15.1%), the timetable after it (8.1%). Hard because a watermark never comes back for them.
8. **Trips the timetable does not know.** An unplanned extra (5%) has no scheduled time, its route is the feed's own. Recovered 0% in your run `[measured]`.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Incremental model + merge | Keep every distinct report and timetable row across nights without duplicates on a rerun | `incremental materialization`, `MERGE / upsert`, `unique key` |
| Raw tables forget | Keep your own history, because raw keeps 5 and 7 nights | `history table`, `late arriving data` |
| Slowly changing dimension (versions) | The timetable version in force on a day | `slowly changing dimension type 2`, `lead() validity window` |
| As-of join | Join a report to the version of its day | `as-of join`, `effective date` |
| Dedup with window functions | One row per key with a tie-break | `row_number() over (partition by)` |
| Settled trip from many events | First valid start, last event decides status | `first_value`, `last_value`, `conditional aggregation` |
| Candidate-day resolution | Try 3 days, keep the nearest departure | `nearest match`, `cross join` |
| Time zones and cutoffs | Service day starts at 07:00 UTC (agency UTC-7) | `AT TIME ZONE`, `business date` |
| GTFS times past 24:00:00 | `25:10:00` belongs to the day before | `GTFS stop_times` |
| Defensive parsing | A bad value must give NULL, not fail the task | `try_cast`, `data quality checks` |

A short example of the time model: a trip on service day D leaves at D 07:00 UTC plus its departure seconds.
```sql
CAST(strftime('%s', service_date || ' 07:00:00') AS INTEGER) + departure_s   -- 25:10:00 is just 90600 seconds
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **5-7 years** | medium | history + idempotent merge for 2 tables, version-in-force join, nearest-day resolution, 30 interacting conditions |
| Your code (`dag.sql`) | **3-5 years** | medium | window dedup and merge in the history tasks (L72-97), schedule dedup and applicable-schedule rank (L323-360), early null-marker clean (L28-55), keyed history that survives the 5/7-night windows |
| Gold code (`gold_submit.sql`) | **6-9 years** | medium | `unique_key` merge for both tables (L19, L28), json key built from fields (L148), version windows with `lead()` (L288-297), candidate-day resolution (L303-333), sortable packed keys carried through `max`/`min` (L335-346) |

- `dag.sql` already keeps both histories and picks a version by effective day, so its structure is sound. The gap to the gold is **coverage of shapes**: departure forms, rail words, `.0` ids, ISO times, and the day on rows that have none.
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined against platform feedback or generated (long repeated `CASE` blocks).

## 7. Common traps

- **Validating a shape too tightly.** Sign: `GLOB '[0-9][0-9]:[0-9][0-9]:[0-9][0-9]'` on a column that also arrives as `7:05` or `07:05`.
- **Digits-only id check.** Sign: `NOT GLOB '*[^0-9]*'` on an id that a spreadsheet saved as `7041203.0`.
- **Fallback to the file's day.** Sign: `COALESCE(start_date, date(batch_id))` for rows whose day is missing exactly because they crossed midnight.
- **Only one vocabulary.** Sign: an `IN ('start','departure', ...)` list with no `departed` / `arrived`.
- **Taking the newest row whole.** Sign: the vehicle comes from the end row, which has none.
- **Joining the timetable by the newest file.** Sign: no effective-day window; a retimed trip is wrong for the days in between.
- **Rank over rows that mapped to NULL.** Sign: the "latest status" is a row whose status could not be read.
- **Reading only tonight's file.** Sign: a watermark filter on `_loaded_at`.

## 8. Mindset difference (you vs gold)

Your file keeps history and uses the version in force, and it avoids the late-file trap by rebuilding from history every night. The gold also **cleans every column the same defensive way first** (same null markers, same time parser, same id rules, same departure parser) and only then ranks and joins. Your DAG accepts one shape in several columns, so a trip is clean in one column and lost in another. The specific bugs, the Before/After code and the measured effect are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** A timetable says a trip leaves at `7:05:00` in one file and `07:05` in another. How do you read both, and what about `25:10:00`? *Hint: normalise to seconds after the service day's start, hours may pass 24.*
2. **(mid)** A report has no service date and it is 00:40 local. Which day is it? *Hint: try the report's day and the 2 days before, keep the one whose departure is nearest.*
3. **(senior)** The new timetable is published on the 9th but starts on the 12th. Which version prices the 10th? *Hint: effective-day windows with `lead()`, join on `day >= effective and day < next`.*
4. **(senior)** An amended file is sent again for the same start date. How do you keep the later one? *Hint: rank by publication time, not by version name.*
5. **(senior)** A bus is swapped at a relief point and a trip is cancelled then covered. What are the vehicle and the status? *Hint: first valid start gives the vehicle, last event gives the status.*
6. **(mid)** The raw table keeps 5 nights and an export lands after the morning run. How do you not lose it? *Hint: rebuild from your own history, not from a watermark.*

## 10. Learning path

**Order of study:** (1) one cleaning rule for every column → (2) versions in force → (3) settle a trip from its reports → (4) resolve a missing day.

**Exercise 1 - Clock zoo (30-45 min).** Make a column with `7:05:00`, `07:05`, `25:10:00`, `0.29`, `''`, `NULL`. Turn every value into seconds. *Self-check:* the same rule is used for every row and bad input gives NULL.

**Exercise 2 - Versions (45 min).** 3 weekly versions, one announced 3 days ahead, one amended. Join 10 service days to the version in force. *Self-check:* each day picks 1 version and an amended file wins over the first.

**Exercise 3 - Settle a trip (45 min).** One trip with a relief bus, a cancel-then-run, an end 2 days later and a start stamped 1970. *Self-check:* vehicle is the first valid start's, status is the last event's, the delay is not 56 years.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 7](https://datadriven.io/community/week-7)
