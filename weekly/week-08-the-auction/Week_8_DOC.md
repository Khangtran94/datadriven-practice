# The Auction
*A search engine sells the few ad slots on every page of results, one auction per search. The advertiser pays only when someone clicks*

You're a data engineer at a search engine that sells a few ad slots around search results. Each slot is sold at auction when someone searches, and advertisers pay only for clicks. The inventory team needs one clean row per ad shown: who it was for, where it appeared, and what it billed. Each night, a job copies two raw tables from two systems. Build the inventory table for ads shown from 2026-10-09 through 2026-11-07; billing's month ended 2026-10-31.

The serving build, click server, and fraud filter came from three teams, each with its own terminology and clock. An older serving build still runs on part of the fleet. The fraud filter may keep reviewing a click for days after it happens. Each data center ships its log on its own schedule, and the copy job has been patched under pressure more than once.

## 1) Raw tables

Two raw tables are landed by a nightly copy job. Column types below are those documented by the ads serving team.

### `ad_events`

A log with one row for every ad shown, every click, and every fraud verdict. There is one file per UTC day, copied the next morning. Only the last three nights are retained. The full table contains 285,128 rows.

| Column | Type | Meaning |
|---|---|---|
| `impression_id` | TEXT | The ad server's ID for the ad shown. |
| `event` | TEXT | Event type: `serve`, `click`, `invalid`, or `valid`. |
| `event_time` | TEXT | Microseconds since 1970, UTC. |
| `customer_id` | TEXT | The advertiser's account. |
| `detail` | TEXT | The slot for a `serve`; the price in micros for a `click`. |
| `_loaded_at` | TEXT | When the copy job began, UTC. |

Sample input: 12 rows, columns in documented order.

| `impression_id` | `event` | `event_time` | `customer_id` | `detail` | `_loaded_at` |
|---|---|---:|---|---|---|
| A3ov7PHu5IgfPo0Zyfyqzw | serve | 1791651772316560 | 2598220763 | top-2 | 2026-10-11 06:41:09+00 |
| A3ov7PHu5IgfPo0Zyfyqzw | click | 1791651777948161 | NULL | 150000 | 2026-10-11 06:41:09+00 |
| A/X2M+b7uKAI6TG03JrKmw | serve | 1791674228494362 | 982-439-1134 | top-2 | 2026-10-11 06:41:09+00 |
| A/f/P6q2S5lPvpOtJXqVjQ | serve | 1791685187612900 | 2338241382 | top-1 | 2026-10-12 06:14:53+00 |
| A3ov7PHu5IgfPo0Zyfyqzw | invalid | 1791745553633122 | NULL | SIVT | 2026-10-12 06:14:53+00 |
| A/hJHLpAczrO4yDYr1f03A | serve | 1791921745569564 | 0493754014 | top-3 | 2026-10-14 13:46:00+00 |
| A/XyAfEyPi3EtpLCjAtMmg | serve | 1792000518515180 | 0493754014 | top-3 | 2026-10-15 06:42:56+00 |
| A/XyAfEyPi3EtpLCjAtMmg | serve | 1792000518515180 | 0493754014 | top-3 | 2026-10-15 06:42:56+00 |
| AtWrr3VSIyG18q8tuIbVYg | serve | 1792089889255101 | 0493754014 | top-1 | 2026-10-16 06:30:30+00 |
| AtWrr3VSIyG18q8tuIbVYg | click | 1792089897726901 | \N | 250000 | 2026-10-16 06:30:30+00 |
| A6Qwt/i1ySJpF1zZ5ba8FA | serve | 1792098211059159 | 2598220763 | top-1 | 2026-10-16 06:30:30+00 |
| A+hcrTW1C3+O7oH0J1CYWA | serve | 1792100501493691 | 2338241382 | top-3 | 2026-10-16 06:30:30+00 |

### `accounts`

A nightly snapshot of advertiser accounts that are open. Only the latest copy is retained. The full table contains 14,872 rows.

| Column | Type | Meaning |
|---|---|---|
| `customer_id` | TEXT | The account, formatted like `123-456-7890`. |
| `time_zone` | TEXT | The account's time zone, an IANA name. |
| `currency_code` | TEXT | The account's currency, ISO 4217. |
| `_loaded_at` | TEXT | When the copy was taken, UTC. |

Sample input: 28 rows, columns in documented order.

| `customer_id` | `time_zone` | `currency_code` | `_loaded_at` |
|---|---|---|---|
| 049-375-4014 | America/Chicago | USD | 2026-10-10 06:27:26+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-10 06:27:26+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-10 06:27:26+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-10 06:27:26+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-11 06:00:43+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-11 06:00:43+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-11 06:00:43+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-11 06:00:43+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-12 05:35:20+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-12 05:35:20+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-12 05:35:20+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-12 05:35:20+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-13 06:18:35+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-13 06:18:35+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-13 06:18:35+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-13 06:18:35+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-14 05:42:25+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-14 05:42:25+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-14 05:42:25+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-14 05:42:25+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-15 05:45:20+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-15 05:45:20+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-15 05:45:20+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-15 05:45:20+00 |
| 049-375-4014 | America/Chicago | USD | 2026-10-16 05:49:47+00 |
| 233-824-1382 | America/New_York | USD | 2026-10-16 05:49:47+00 |
| 259-822-0763 | Pacific/Honolulu | USD | 2026-10-16 05:49:47+00 |
| 982-439-1134 | America/Sao_Paulo | BRL | 2026-10-16 05:49:47+00 |

## 2) Target table: `ad_impressions`

The target has exactly these columns, one row per key. `impression_id` is the ad server's 22-character base64 ID and the exact row identity; duplicate rows for the same key are incorrect. Ads on a search partner's site are the partner's, not ours, and should not produce a row. A serve made with `adtest` on is a preview and should not produce a row.

| Column | Type / constraints | Required value |
|---|---|---|
| `impression_id` | TEXT, key, not null | Exact impression ID; one row per value. A number is incorrect. |
| `customer_id` | TEXT, not null | Advertiser account as 10 digits without dashes. A number is incorrect. |
| `served_at` | timestamp, not null | Ad display instant in UTC, represented as ISO 8601 text at seconds precision. The instant must match exactly. |
| `served_date` | TEXT, not null | `YYYY-MM-DD`, the display day in the account's time zone. A number is incorrect. |
| `slot` | nullable enum | One of `top-1` through `top-4` or `bottom-1` through `bottom-3`; anything else is NULL. NULL is also required when the source has no usable value. The ad server calls the block above the results the mainline. |
| `clicked` | bool, not null | `1` if the ad was clicked, regardless of what the fraud filter later decided; otherwise `0`. Store as INTEGER 1 or 0 only. |
| `billed_micros` | int, not null | Sum of the first two clicks with a price, in micros of the account's currency. A click is billed as 0 when the filter's latest verdict is `invalid`. Store as INTEGER, not TEXT. |

The expected sample output contains 8 rows:

| `impression_id` | `customer_id` | `served_at` | `served_date` | `slot` | `clicked` | `billed_micros` |
|---|---|---|---|---|---|---:|
| A3ov7PHu5IgfPo0Zyfyqzw | 2598220763 | 2026-10-10T17:02:52Z | 2026-10-10 | top-2 | true | 0 |
| A/X2M+b7uKAI6TG03JrKmw | 9824391134 | 2026-10-10T23:17:08Z | 2026-10-10 | top-2 | false | 0 |
| A/f/P6q2S5lPvpOtJXqVjQ | 2338241382 | 2026-10-11T02:19:47Z | 2026-10-10 | top-1 | false | 0 |
| A/hJHLpAczrO4yDYr1f03A | 0493754014 | 2026-10-13T20:02:25Z | 2026-10-13 | top-3 | false | 0 |
| A/XyAfEyPi3EtpLCjAtMmg | 0493754014 | 2026-10-14T17:55:18Z | 2026-10-14 | top-3 | false | 0 |
| AtWrr3VSIyG18q8tuIbVYg | 0493754014 | 2026-10-15T18:44:49Z | 2026-10-15 | top-1 | true | 250000 |
| A6Qwt/i1ySJpF1zZ5ba8FA | 2598220763 | 2026-10-15T21:03:31Z | 2026-10-15 | top-1 | false | 0 |
| A+hcrTW1C3+O7oH0J1CYWA | 2338241382 | 2026-10-15T21:41:41Z | 2026-10-15 | top-3 | false | 0 |

Every sample output row is a real row. The sample is honest and small; the full tables may contain additional production history and nightly loads. After the DAG's last run, every target cell is compared with the correct value. A right value earns +1; a right NULL also earns +1; NULL where a source value exists earns 0; a wrong value earns -1; an extraneous row or duplicate key earns -2. Types are strict.

## 3) Notes from the inventory team

- Prices are in micros (1,000,000 micros per currency unit) and are multiples of 10,000.
- An advertiser's day and month are determined by the account's own time zone.
- An ad uses the time zone from the latest account copy before it; if there is no prior copy, use the first copy.
- A fraud verdict reached after the click's month has closed counts in the following month.
- A click reaches the log through the link in the ad.
- Clicked status is based on whether a click occurred, even if the latest fraud verdict later makes the click unbillable.
- The target bills the first two clicks with a price, with an invalid latest verdict making that click's billed amount zero.
- Serving, click, and fraud events can use different terminology and clocks. The older serving build, delayed fraud review, different data-center shipping schedules, and copy-job patches are reasons the full data may be messier than the sample; do not assume the sample covers every case.

## 4) Expected sample output

The sample has 12 `ad_events` rows and 28 `accounts` rows. The expected `ad_impressions` target has 8 rows.

## 5) The schedule

- Data window: 30 nights, from 2026-10-09 through 2026-11-07; the window runs from 2026-10-09 08:00:00 UTC to 2026-11-08 08:00:00 UTC.
- Default schedule: nightly at 08:00 UTC (`0 8 * * *`), oldest first. `schedule: nightly` runs the DAG 30 times, once per night. Any cron inside those nights can be set on the DAG or on one task. Each nightly run's logical date (`{{ ds }}`) is the day its data interval starts.
- At each run, raw tables are visible as the landing held them at that time: `ad_events` retains the last three nights, and `accounts` contains only the latest night's copy.
- Write a DAG in `dag.yml` and one SQL file per task/table. Each SQL file is one SELECT; the file named `ad_impressions` produces the scored target. A file may read only raw tables or tasks it depends on.
- Supported SQL includes window functions, CTEs, JSON functions, date functions, and functions shared by the accepted dialects. Values are compared as stored; TEXT sorts as text until cast.
- The 512 MB memory budget and 10-minute runtime cap apply to the entire schedule. The cap is a pass/fail gate, not a score.
- The challenge dropped Monday 2026-11-02 at 16:00 UTC. Submissions freeze Sunday 2026-11-08 at 16:00 UTC, results post at the freeze, and the next drop is Monday 2026-11-09 at 16:00 UTC. Submit as often as desired; the last submission before the freeze counts.
- Scoring prioritizes accuracy. If two DAGs have the same score, the one doing less work per raw row over the full schedule ranks higher.
