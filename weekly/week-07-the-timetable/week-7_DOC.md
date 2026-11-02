# Week 7 — The Timetable

## 1) Raw tables

Two raw tables, landed by a nightly copy job. Each column carries the type the ingest team documented for it.

### `trip_updates`

- A log: 1 row per start, end or cancellation a vehicle reported.
- 1 file per calendar day, cut at midnight on the agency's clock.
- Only the last 5 nights are kept.
- 248,460 rows in the full table.
- Columns:
  - `update_id` TEXT — the ingest's id for the report
  - `trip_id` TEXT — the timetable's trip id
  - `start_date` TEXT — the trip's service day, YYYYMMDD
  - `route_id` TEXT — the route, when the feed sent one
  - `vehicle_id` TEXT — the fleet number
  - `event_type` TEXT — start, end or cancel
  - `schedule_relationship` TEXT — SCHEDULED, ADDED or CANCELED
  - `event_time` TEXT — the unit's clock, seconds since 1970
  - `feed` TEXT — bus or rail: the supplier's feed
  - `_batch_id` TEXT — the calendar day the file covers
  - `_loaded_at` TEXT — when the export run began, UTC

Sample rows of the raw table: `trip_updates`, 16 rows, each a JSON array in column order.

| update_id | trip_id | start_date | route_id | vehicle_id | event_type | schedule_relationship | event_time | feed | _batch_id | _loaded_at |
|---|---|---|---|---|---|---|---|---|---|---|
| tu2466544897 | 1942462 | 20261004 | NULL | 2594 | end | SCHEDULED | 1791123778 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu2466544897 | 1942462 | 20261004 | NULL | 2594 | end | SCHEDULED | 1791123778 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu2743567048 | 2726443 | 20261003 | NULL | 2499 | start | SCHEDULED | 1791105057 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu3882877296 | 1071372 | 20261004 | NULL | 2545 | start | SCHEDULED | 1791171445 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu5398002809 | 2726443 | 20261003 | NULL | 2499 | end | SCHEDULED | 1791107460 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu6537313057 | 1071372 | 20261004 | NULL | 2545 | end | SCHEDULED | 1791173470 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu7170406416 | 2338412 | 20261004 | \N | 1362 | start | SCHEDULED | 1791167887 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu7306090016 | 1784082 | 20261004 | NULL | 2372 | start | SCHEDULED | 1791131100 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu9812109136 | 1942462 | 20261004 | NULL | 2594 | start | SCHEDULED | 1791117801 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu9824842177 | 2338412 | 20261004 | \N | 1362 | end | SCHEDULED | 1791173572 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu9960525777 | 1784082 | 20261004 | NULL | 2372 | end | SCHEDULED | 1791137006 | bus | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu2081081696 | 3130312 | 20261004 | NULL | NULL | cancel | CANCELED | 1791148320 | rail | 2026-10-04 | 2026-10-05 12:04:54+00 |
| tu2156171305 | 1031777 | 20261005 | NULL | 1340 | end | SCHEDULED | 1791228910 | bus | 2026-10-05 | 2026-10-06 15:32:11+00 |
| tu9501735544 | 1031777 | 20261005 | NULL | 1340 | start | SCHEDULED | 1791224813 | bus | 2026-10-05 | 2026-10-06 15:32:11+00 |
| tu4435259632 | 4191458 | 20261006 | NULL | 1355 | start | SCHEDULED | 1791354714 | bus | 2026-10-06 | 2026-10-07 11:56:44+00 |
| tu7089695393 | 4191458 | 20261006 | NULL | 1355 | end | SCHEDULED | 1791357807 | bus | 2026-10-07 | 2026-10-08 11:47:08+00 |

### `trips`

- The timetable: every trip's first departure, the whole table in each version.
- Only the last 7 nights are kept.
- 51,541 rows in the full table.
- Columns:
  - `trip_id` TEXT
  - `route_id` TEXT
  - `service_id` TEXT — the days the trip runs: WKD, SAT or SUN
  - `direction_id` TEXT — 0 or 1
  - `trip_headsign` TEXT
  - `first_departure` TEXT — HH:MM:SS on the agency's clock; it may pass 24:00:00
  - `feed_version` TEXT — the file's version
  - `feed_start_date` TEXT — the first day the version applies, YYYYMMDD
  - `_batch_id` TEXT — the day the file was published
  - `_loaded_at` TEXT — when the export run began, UTC

Sample rows of the raw table: `trips`, 16 rows, each a JSON array in column order.

| trip_id | route_id | service_id | direction_id | trip_headsign | first_departure | feed_version | feed_start_date | _batch_id | _loaded_at |
|---|---|---|---|---|---|---|---|---|---|
| 1031777 | 4 | WKD | 0 | Southside | 11:25:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 1071372 | 1 | SUN | 1 | University | 20:17:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 1784082 | 1 | SUN | 1 | Downtown | 09:20:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 1942462 | 2 | SUN | 1 | Central Station | 05:37:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 2338412 | 9 | SUN | 1 | Northgate | 19:33:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 2726443 | 2 | SAT | 0 | Riverside | 26:04:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 3130312 | L4 | SUN | 1 | Northgate | 16:19:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 4191458 | 9 | WKD | 1 | Harbor | 23:31:00 | 20261002 | 20260922 | 2026-10-02 | 2026-10-03 12:18:05+00 |
| 1031777 | 4 | WKD | 0 | Southside | 11:25:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 1071372 | 1 | SUN | 1 | University | 20:17:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 1784082 | 1 | SUN | 1 | Downtown | 09:20:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 1942462 | 2 | SUN | 1 | Central Station | 05:37:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 2338412 | 9 | SUN | 1 | Northgate | 19:33:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 2726443 | 2 | SAT | 0 | Riverside | 26:04:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 3130312 | L4 | SUN | 1 | Northgate | 16:19:00 | 20261002 | 20260922 | 2026-10-09 | 2026-10-10 12:17:13+00 |
| 4191458 | 9 | WKD | 1 | Harbor | 23:31:00 | 20261009 | 20261009 | 2026-10-09 | 2026-10-10 12:17:13+00 |

## 2) Target table: `trip_actuals`

The target table has exactly these columns.

| Column | Type | Requirement |
|---|---|---|
| `trip_id` | text, KEY, not null | The timetable's trip id; for an extra trip, the id the feed gave. TEXT; a number is wrong. The row identity: one row per value, matched exactly. A second row for the same value costs 2. |
| `service_date` | text, KEY, not null | `YYYY-MM-DD`: the service day the trip belongs to. For a trip the timetable lacks, the agency's calendar day it started on. TEXT; a number is wrong. |
| `route_id` | text, nullable | The timetable's route for the trip. For a trip the timetable lacks, the route the feed gave. NULL when the source has no usable value. |
| `scheduled_start` | timestamp, nullable | The timetable's first departure, in UTC. Null for a trip the timetable lacks. TEXT, ISO 8601 in UTC, seconds precision; a different instant is wrong. |
| `actual_start` | timestamp, nullable | The first start a vehicle reported, in UTC; null if none. A time before the service day is no departure: null. TEXT, ISO 8601 in UTC, seconds precision. |
| `delay_s` | int, nullable | `actual_start` minus `scheduled_start`, in whole seconds. Null when either is null. INTEGER, not TEXT; `'4'` is wrong. |
| `status` | enum, nullable | The trip's last reported state: `completed`, `started` or `cancelled`. Anything else is null. |
| `vehicle_id` | text, nullable | The fleet number of the vehicle that first started the trip, digits only. Null if no vehicle started it. TEXT; a number is wrong. |
| `unscheduled` | bool, not null | 1 for a trip the timetable in force on its service day does not list. INTEGER 1 or 0, nothing else. |

This is the table service planning gets: exactly these columns, one row per key. After the DAG's last run, every cell is compared with the correct value. For nullable fields, a right NULL scores +1 and a wrong value scores -1.

Sample rows of the target table: `trip_actuals`, 8 rows.

| trip_id | service_date | route_id | scheduled_start | actual_start | delay_s | status | vehicle_id | unscheduled |
|---|---|---|---|---|---:|---|---|---|
| 2726443 | 2026-10-03 | 2 | 2026-10-04T09:04:00Z | 2026-10-04T09:10:57Z | 417 | completed | 2499 | false |
| 1071372 | 2026-10-04 | 1 | 2026-10-05T03:17:00Z | 2026-10-05T03:37:25Z | 1225 | completed | 2545 | false |
| 1784082 | 2026-10-04 | 1 | 2026-10-04T16:20:00Z | 2026-10-04T16:25:00Z | 300 | completed | 2372 | false |
| 1942462 | 2026-10-04 | 2 | 2026-10-04T12:37:00Z | 2026-10-04T12:43:21Z | 381 | completed | 2594 | false |
| 2338412 | 2026-10-04 | 9 | 2026-10-05T02:33:00Z | 2026-10-05T02:38:07Z | 307 | completed | 1362 | false |
| 3130312 | 2026-10-04 | L4 | 2026-10-04T23:19:00Z | NULL | NULL | cancelled | NULL | false |
| 1031777 | 2026-10-05 | 4 | 2026-10-05T18:25:00Z | 2026-10-05T18:26:53Z | 113 | completed | 1340 | false |
| 4191458 | 2026-10-06 | 9 | 2026-10-07T06:31:00Z | 2026-10-07T06:31:54Z | 54 | completed | 1355 | false |

## 3) Notes from service planning

- Timetable departure times after `24:00:00` belong to the previous day.
- The agency clock is seven hours behind UTC year-round.
- Each timetable version applies from its start date until the next version starts.
- Trips with no start, end, or cancellation report do not appear in the output.
- An export run's start time is stamped on all its files.

## 4) Expected sample output

The sample has **16 trip-update rows, 16 timetable rows, and 8 expected target rows**. The expected rows are shown under Section 2 with the target table.

## 5) The schedule

Run nightly at **13:00 UTC** for 30 nights, **2026-10-02 through 2026-10-31**. The run window ends at 2026-11-01 13:00 UTC. Each run sees the last 5 nights of `trip_updates` and the last 7 nights of `trips`. The full DAG has a 512 MB memory budget and a 10-minute runtime cap.
