# Week 7: The Timetable

*A transit agency's buses and trains report every trip they run. The timetable they run against changes every week.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-7)

You're a data engineer at a city bus and light rail agency. Each bus and train reports its trips as it runs them, and the service planning team needs 1 clean row per trip: when it was due, when it left, and how late it was. Each night, a job copies 2 raw tables out of 2 systems. The realtime ingest provides trip_updates, a log with a row for every start, end or cancellation a vehicle reported, 1 file per day. The planning team's schedule export provides trips, the timetable with every trip's first departure, published whole as a new version about once a week. Write the DAG that builds the planners' trip table for the days from 2026-10-02 to 2026-10-31.

## Result

| | |
|---|---|
| Score | 0.7846 |
| Rank | #5 of 9, top 56% |
| Points | +20 |
| Rows built | 100,792 of 107,965 |
| Work per raw row | 1.0x median |
| Statements | 5 |
| Scored | 2026-11-01 |

1,223 rows matched no record. Together they cost 2,446 points.

## Columns

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

## What the tables held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of tables | Recovered | Handled |
|---|---:|---:|:---:|
| Times in 3 forms in the files | 38.4% | 78% | yes |
| Start dates with dashes | 20.6% | 72% | no |
| Times as millis or ISO text | 18.0% | 67% | no |
| Start and end, in other words | 14.0% | 62% | no |
| An unplanned extra trip | 5.0% | 0% | no |
| End rows with no fleet number | 21.6% | 80% | yes |
| Exported after the run began | 23.8% | 81% | yes |
| NULL written as text | 25.0% | 83% | yes |
| The same row twice in a file | 20.0% | 80% | yes |
| A trip retimed in a later file | 17.2% | 81% | yes |
| Fleet numbers in other forms | 14.0% | 75% | no |
| A trip past 24:00:00 | 11.1% | 73% | no |
| The day left off the row | 25.0% | 64% | no |
| Rail rows after the run began | 15.1% | 82% | yes |
| Dates with dashes in them | 12.0% | 82% | yes |
| Left ahead of its time | 9.5% | 79% | yes |
| Reported across 2 files | 10.8% | 83% | yes |
| Trips file after the run began | 8.1% | 80% | yes |
| Old rows sent in a newer file | 8.0% | 80% | yes |
| A route id the poller cached | 10.0% | 84% | yes |
| Its end came in days later | 7.9% | 82% | yes |
| Trip ids with .0 on the end | 6.6% | 80% | yes |
| Trip ids with blanks | 5.0% | 80% | yes |
| A relief bus took over | 4.7% | 79% | yes |
| Announced ahead of its day | 5.3% | 83% | yes |
| A unit clock not yet set | 2.5% | 79% | yes |
| A cancelled trip | 4.5% | 91% | yes |
| Withdrawn, then it ran | 2.1% | 81% | yes |
| A trip moved to a new route | 1.3% | 83% | yes |
| A file sent again, amended | 1.1% | 89% | yes |

### Why these happen

**Times in 3 forms in the files.** GTFS allows a departure with 1 digit of hours, and the planners' tool drops the seconds in another version. A fixed-position read of HH:MM:SS takes 7:05:00 as 7 hours and 5 seconds.

**Start dates with dashes.** One version's file writes the start date as 2026-10-23 where the others write 20261023. Compared as text against a date, it never sorts where it belongs.

**Times as millis or ISO text.** The bus units count seconds since 1970; the rail units count milliseconds, and 1 build of their firmware writes ISO text, some of it in the agency's local time with its offset. As text the forms sort in no useful order, so the last report and the first start are picked wrong.

**Start and end, in other words.** The 2 suppliers' units name the same report their own way: DEPARTED or departure for a start, ARRIVED or arrival for an end, CANCELLED or canceled for a cancellation. The column is free text and nobody mapped one vocabulary onto the other.

**An unplanned extra trip.** The dispatcher puts an extra vehicle on a busy route, and the feed reports it as a trip the timetable does not list. It has no row in the schedule, so its route is the feed's own and it has no scheduled departure to be late against.

**End rows with no fleet number.** The arrival message carries the stop and the time and leaves the vehicle field empty. The vehicle is known from the start; taking the newest row whole loses it.

**Exported after the run began.** The export runs after the last trip of the day ends, and on some nights it starts hours late; once it ran the next afternoon. That day's reports are first seen by the run after, under the earlier day's file. A pipeline that takes only the night's file never sees them.

**NULL written as text.** A text export has to write NULL somehow, and each tool picks its own marker. Loaded into a text column the marker is a value like any other, so a trip with no vehicle looks like it had one named NULL.

**The same row twice in a file.** The ingest polls the feed every 30 seconds and stores what it gets; a poll that overlaps the last one stores the same report again, under the same id and the same stamp.

**A trip retimed in a later file.** The planners move a trip's departure in a new version of the timetable. The version in force on the service day decides the scheduled time; the first file's time, or the newest file's, is wrong for the days in between.

**Fleet numbers in other forms.** The fleet number is painted on the vehicle and typed into each unit at installation: with leading zeros, with blanks, or with BUS or RAIL in front. The number is the same; the text is not.

**A trip past 24:00:00.** A GTFS timetable counts a service day past 24 hours: a 25:10:00 departure runs at 01:10 the next calendar day and belongs to the day before. Its reports are in the next day's file, and a function that reads 25:10:00 as a time of day reads nothing.

**The day left off the row.** The service day is optional in GTFS-RT. The rail units fill it from an operating-day register that is blank after midnight until the unit restarts at the depot, so the reports after midnight are the ones without it, and those are exactly the reports whose calendar day is not their service day. The day has to be worked out from the timetable: the candidate day whose departure is nearest the report.

**Rail rows after the run began.** The nightly export stamps every file it writes with the time the run began, and the loader takes the files in turn, the rail file last. On a night the run began late enough, the rail rows arrive after the morning run with a stamp the run already read past: a watermark that takes only stamps newer than the last it saw never comes back for them, and only a lookback, a merge over the whole window, or a sensor that waits for both feeds holds them.

**Dates with dashes in them.** GTFS-RT writes a service day as 8 digits, and the ingest's newer build writes it with dashes. Both name the same day; as text they are 2 keys, so 1 trip lands in the table twice.

**Left ahead of its time.** A bus leaves a timepoint early, which the planners count as a fault: the delay is negative, not zero and not its absolute value.

**Reported across 2 files.** A file is cut at midnight on the agency's clock, and a trip that is running at midnight has its start in one day's file and its end in the next. The table is a log of reports; the row the planners want is the trip, settled across its files.

**Trips file after the run began.** The timetable file for the new version landed after the morning run on a night the old one had already dropped out of the table. A run that reads the table as it stands finds no timetable at all and writes every trip of the day as one the schedule does not list; a sensor waits, a kept history carries the versions it has, and the next run revisits the day.

**Old rows sent in a newer file.** When a day's export is run again by hand it re-exports every report the ingest still holds, under the day it ran. The same report then sits in 2 files, and the file's day says nothing about the trip's.

**A route id the poller cached.** The ingest fills the route on a report from a cache keyed by trip id, loaded when the ingest started. When the timetable moves a trip to another route the cache still names the old one, so the feed's route is right only for a trip the timetable has no row for.

**Its end came in days later.** A unit that loses its link holds its reports and sends them when it reconnects, days later for a vehicle parked at the depot. A run already wrote the trip as started; the end arrives under a later day's file, and only a pipeline that revisits the trip changes the row.

**Trip ids with .0 on the end.** A planner opens the trips file in a spreadsheet before it goes out, and the tool saves every numeric id as a decimal. 7041203.0 is not 7041203 to a join, so the trip looks like one the timetable does not list.

**Trip ids with blanks.** The rail units send the trip id inside a fixed-width field, and the ingest keeps the blanks. The id no longer equals the timetable's, so the trip looks like one the timetable does not list.

**A relief bus took over.** A vehicle is swapped at a relief point, and the second one reports a start of its own. The trip started once, with the first vehicle; taking the latest start, or the last vehicle, names the wrong one.

**Announced ahead of its day.** A timetable file is published a few days before it takes effect, with its start date in it. Until that day the earlier version is in force, so applying the newest file the night it lands retimes the days in between.

**A unit clock not yet set.** A unit that boots at the depot reports its first trip before its GPS has set the clock, so the start is stamped 1970 or 1980. The report is real and the vehicle is right; the time is no time, and a delay computed from it is 56 years.

**A cancelled trip.** The dispatcher cancels a trip in the feed, and no vehicle ever reports it. The trip has a row all the same: its status is the cancellation, and nothing of a departure is known.

**Withdrawn, then it ran.** A trip cancelled for lack of a driver is covered after all, and the vehicle reports it as usual. The cancellation and the reports are all in the log, and the last of them is what happened.

**A trip moved to a new route.** A trip is moved to a neighbouring route in a new version. The route is the version's in force on the day, and the feed's cached route id, where it sends one, still says the old route.

**A file sent again, amended.** A timetable file goes out with wrong times for a few trips and is sent again the next day for the same start date. Both land; the later publication is the one the agency ran, and a history keyed on the version alone keeps whichever came first.

Concepts exercised: sqlBasicTypes, sqlCaseWhen, sqlCast, sqlCoalesce, sqlConcat, sqlCte, sqlDateFormat, sqlDateTrunc, sqlDateVsTimestamp, sqlDistinct, sqlExtract, sqlInList, sqlInnerJoin, sqlIsNull, sqlLeftJoin, sqlLength, sqlLimit, sqlLowerUpper, sqlMultipleJoins, sqlMultipleWindows, sqlPartitionBy, sqlReplace, sqlRowNumber, sqlSelectFrom, sqlSelfJoin, sqlStringBuilding, sqlSubqueryScalar, sqlSubstring, sqlTimestampType, sqlTrim, sqlWhere, sqlWindowDedup

## Submission

The DAG that was graded is in [`dag.sql`](./dag.sql).
