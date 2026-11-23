# Week 10 — The Ceiling

You're a data engineer at an airline. Every airport reports its weather about once an hour as a METAR, a short line of code that pilots read. Collectors logged each METAR as one JSON line, and dispatch needs one clean row per report to study delays around New Year.

## 1) Raw input

The input is a stream of one JSON object per line. The full stream has 1,000,000 records. Each record documents `received_at` (string, ISO 8601 UTC collector-log time), `feed` (string, collector name), and `report` (string, one METAR or SPECI report). The exposed sample contains 10 records. One sample record also has the collector-specific `circuit` field; it is retained below, but collector extras are bookkeeping.

Sample JSON fields are shown in first-seen order across the records: `report`, `feed`, `received_at`, `circuit`. `*not present*` means the JSON key is absent.

| report                                                                                              | feed     | received\_at            | circuit       |
| --------------------------------------------------------------------------------------------------- | -------- | ----------------------- | ------------- |
| `METAR KSFO 300151Z 35015G22KT 10SM FEW040 19/14 A3034 RMK AO1 PK WND 35025/0128 SLP282 T01940140 ` | `usa-3 ` | `2025-12-30T01:58:36Z ` | *not present* |
| `METAR KSFO 300251Z 33012KT 6SM -RA BR FEW010 BKN040 20/14 A3036 RMK AO1 P0015 SLP274 T02020140 `   | `usa-3 ` | `2025-12-30T02:58:31Z ` | *not present* |
| `METAR KSFO 301651Z 35012KT 10SM SCT070 SCT090 17/13 A3051 RMK AO1 SLP335 T01660133= `              | `usa-3 ` | `2025-12-30T16:54:44Z ` | *not present* |
| `METAR KSFO 302151Z 01010KT 330V050 10SM -DZ SCT030 OVC080 20/14 A3052 RMK AO1 SLP339 T01960142 `   | `usa-3 ` | `2025-12-30T21:58:57Z ` | *not present* |
| `METAR EGLL 300120Z 20010KT 9999 SCT025 05/01 Q1016 `                                               | `eur-2 ` | `2025-12-30T01:24:45Z ` | *not present* |
| `METAR EGLL 300420Z 15013KT 9999 FEW035 BKN045 06/02 Q1017 `                                        | `eur-2 ` | `2025-12-30T04:22:59Z ` | `GTS `        |
| `METAR EGLL 301520Z 19017G29KT 4500 -RA BKN025 OVC095 10/08 Q1021 `                                 | `eur-2 ` | `2025-12-30T15:26:47Z ` | *not present* |
| `SPECI EGLL 310048Z 20010KT 9999 BKN040 OVC060 06/03 Q1021 `                                        | `eur-2 ` | `2025-12-31T00:55:19Z ` | *not present* |
| `KATL 300154Z AUTO 10010KT 6SM BR BKN030 OVC080 13/10 A2965 RMK AO2 SLP049 T01270100 $ `            | `usa-1 ` | `2025-12-30T01:56:13Z ` | *not present* |
| `KATL 300854Z AUTO 11014KT 1SM BR SCT020 BKN030 OVC060 12/11 A2973 RMK AO2 SLP074 T01180108= `      | `usa-1 ` | `2025-12-30T08:59:11Z ` | *not present* |

## 2) Target table

The brief does not name a physical target table. Emit exactly one row per airport and observation time, with exactly these columns and types:

| Column           | Type    | Key / nullability | Requirements                                                                                                             |
| ---------------- | ------- | ----------------- | ------------------------------------------------------------------------------------------------------------------------ |
| `station `       | text    | key, not null     | Four-letter ICAO code as given by the report; exact row identity.                                                        |
| `observed_at `   | text    | key, not null     | UTC timestamp formatted like `2025-12-31T18:51:00Z`; exact row identity.                                                 |
| `wind_kt `       | int     | nullable          | Mean wind speed to nearest knot, not gust speed.                                                                         |
| `visibility_m `  | int     | nullable          | Nearest meter, capped at 9999; one statute mile is 1609.344 meters.                                                      |
| `ceiling_ft `    | int     | nullable          | Height in feet of the lowest layer covering more than half the sky; obscured-sky vertical visibility counts as ceiling.  |
| `temp_c `        | numeric | nullable          | Celsius, to the tenth where reported; output must be a string with exactly one decimal place.                            |
| `altimeter_hpa ` | numeric | nullable          | hPa, rounded to one decimal; one inch of mercury is 33.8639 hPa. Output must be a string with exactly one decimal place. |

Integer columns must contain whole numbers, not strings. For nullable fields, use null when the source has no usable value. Every cell is scored: a correct value or null earns +1, a missing value where the source has one earns 0, and a wrong value earns -1\. An extraneous row or a second row for the same key costs -2\. The last row for a key is the one scored. The expected sample output contains 10 rows.

| station | observed\_at            | wind\_kt | visibility\_m | ceiling\_ft | temp\_c | altimeter\_hpa |
| ------- | ----------------------- | -------- | ------------- | ----------- | ------- | -------------- |
| `KSFO ` | `2025-12-30T01:51:00Z ` | 15       | 9999          | NULL        | `19.4 ` | `1027.4 `      |
| `KSFO ` | `2025-12-30T02:51:00Z ` | 12       | 9656          | 4000        | `20.2 ` | `1028.1 `      |
| `KSFO ` | `2025-12-30T16:51:00Z ` | 12       | 9999          | NULL        | `16.6 ` | `1033.2 `      |
| `KSFO ` | `2025-12-30T21:51:00Z ` | 10       | 9999          | 8000        | `19.6 ` | `1033.5 `      |
| `EGLL ` | `2025-12-30T01:20:00Z ` | 10       | 9999          | NULL        | `5.0 `  | `1016.0 `      |
| `EGLL ` | `2025-12-30T04:20:00Z ` | 13       | 9999          | 4500        | `6.0 `  | `1017.0 `      |
| `EGLL ` | `2025-12-30T15:20:00Z ` | 17       | 4500          | 2500        | `10.0 ` | `1021.0 `      |
| `EGLL ` | `2025-12-31T00:48:00Z ` | 10       | 9999          | 4000        | `6.0 `  | `1021.0 `      |
| `KATL ` | `2025-12-30T01:54:00Z ` | 10       | 9656          | 3000        | `12.7 ` | `1004.1 `      |
| `KATL ` | `2025-12-30T08:54:00Z ` | 14       | 1609          | 3000        | `11.8 ` | `1006.8 `      |

## 3) Notes from dispatch

* The log spans the same four days and contains each airport's reports one after another. An airport may send missed reports after reconnecting.
* A report identifies its day of the month and observation time, but not its month. Reconstruct the UTC observation timestamp from the available context.
* There is one output row per airport and observation time. If an airport reports the same time again, the copy logged last stands.
* `received_at`, `feed`, and other collector extras are bookkeeping, not report values.
* Countries and reporting formats vary. Some reports use an older relay format; do not assume every report has identical leading tokens or field placement.
* A collector reads its circuit a line at a time; a long report takes 2.
* Return null for a field with no usable source value. Preserve strict output types and the specified one-decimal formatting for temperature and altimeter.

## 4) Expected sample output

The sample has 10 input stream records and 10 expected target rows. The complete expected rows appear under Section 2.

## 5) The schedule

* Week 10 drops Monday, November 16 at 16:00 UTC.
* Submissions freeze Sunday, November 22 at 16:00 UTC; results post at the freeze.
* The next challenge drops Monday, November 23 at 16:00 UTC.
* Submit as often as desired before the freeze; the last submission is the one that runs against the hidden data.
* The handler is called once per input line, in stream order, then `finalize()` is called after the last line. It must handle 1,000,000 lines.
* Runtime: Python 3.12, standard library only. Allowed imports: `collections`, `csv`, `dataclasses`, `datetime`, `decimal`, `enum`, `functools`, `hashlib`, `html`, `itertools`, `json`, `math`, `re`, `string`, `time`, `typing`, `unicodedata`, and `zoneinfo`. No network or file access.
* Memory budget: 512 MB. Runtime cap: 10 minutes for the full stream; exceeding either limit stops the run and scores it like a crash.
