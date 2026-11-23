---
week: 10
folder: week-10-the-ceiling
title: The Ceiling
format: python
domain: Aviation / Airline operations – METAR weather reports
difficulty: 4
yoe_problem: 4-6
yoe_you: 3-4
yoe_gold: 5-7
confidence_you: medium
score: 0.8185
rank: 4/6
analysis: yes
---

# Week 10: The Ceiling – Challenge Overview

Python streaming handler · score 0.8185 · rank #4 of 6 · analysis: [GPT_Analysis.md](./GPT_Analysis.md)

## 1. The problem in one paragraph

An airline dispatch team wants a clean weather-observation table to study delays around New Year. Airports report weather in METAR format, and collectors store each report inside a JSON log record. The task is to process the incoming stream and produce one row per airport observation with the station, UTC observation time, wind speed, visibility, ceiling, temperature, and altimeter setting. The difficulty is not simply decoding standard METAR groups: the stream contains hand-entered variations, collector wrappers, bulletin headers, lower-case text, reports split across log lines, delayed reports, corrections, duplicate deliveries, and timestamps that cross a month or year boundary.

## 2. Domain and operational context

**Domain: aviation weather and airline operations.**

METAR is a standardized aviation weather report used by pilots, airports, dispatch teams, and flight-planning systems. A single report can contain:
- The observing station and observation time.
- Wind direction, sustained speed, and optional gusts.
- Horizontal visibility and present weather.
- Cloud layers and vertical visibility.
- Air temperature and dew point.
- Altimeter pressure.

The downstream use case is operational analysis: joining weather observations to flight activity and studying weather-related delays. That makes correctness of station identity, UTC timestamps, units, and observation-versus-forecast separation essential.

This challenge deliberately mixes standardized METAR messages with less standardized collector and manually typed forms. The parser must understand both the aviation meaning and the transport context.

## 3. Input and output contract

### Input

- A stream of JSON log records, generally one record per line.
- The report may appear under different keys or inside nested collector envelopes.
- A relay may use \`msg\` for the report and \`ts\` for the receipt timestamp.
- The receipt timestamp may be ISO text, epoch time, or an offset-aware local timestamp.
- A report may be wrapped by a bulletin/archive header or continued on the next log line.
- Reports can be late, repeated, or corrected.

### Output

One row per unique airport observation, identified by \`(station, observed_at)\`.

| Field | Meaning | Expected representation |
|---|---|---|
| \`station\` | Four-letter ICAO airport/station identifier | String |
| \`observed_at\` | Time the weather was observed | UTC timestamp string |
| \`wind_kt\` | Mean wind speed | Integer knots |
| \`visibility_m\` | Horizontal visibility | Integer metres; 9999 represents 10 km or more |
| \`ceiling_ft\` | Lowest broken/overcast layer or vertical visibility | Integer feet |
| \`temp_c\` | Air temperature | String with exactly one decimal place |
| \`altimeter_hpa\` | Altimeter setting converted to hectopascals | String with exactly one decimal place |

Unavailable measurements should be null. A missing measurement is not the same as a malformed output type: downstream scoring checks both the value and its representation.

### Identity and correction rule

The identity of an observation is the airport plus observation time, not the source line or collector record. When a report is sent again with a correction, the last logged copy wins. The final output must contain one row for each key.

## 4. What makes the input difficult

The README describes 28 conditions. The highest-impact categories include:

1. **Hand-entered split groups (17.2%):** \`30007 KT\`, \`180/12KT\`, \`10 SM\`, \`BKN 015\`, \`22 / 14\`, and \`A 3001\`.
2. **Nonstandard units and labels (15.9%):** \`KTS\`, \`CALM\`, \`10KM\`, \`QNH1013\`, \`1013HPA\`, and \`A30.01\`.
3. **Changing JSON key order (30.0%):** object key order must never determine parsing behavior.
4. **Observation time without Z (2.9%):** the report may omit the UTC marker or spell it as \`UTC\`.
5. **Bulletin headers (4.0%):** a prefix such as \`SAUS70 KWBC 311900\` appears before the airport report.
6. **Negative temperatures (13.8%) and shortened/signed forms (6.5%):** \`M05\`, \`-05\`, \`M5\`, and \`5/M1\`.
7. **CAVOK (12.6%):** visibility is at least 10 km and no ceiling is reported by the ordinary cloud groups.
8. **Trailing equals (12.0%):** the wire-format terminator may remain in the collector text.
9. **Reports split across two log lines (6.0%):** the continuation has no station/time header of its own.
10. **Wind in metres per second (7.4%):** convert to knots before output.
11. **Collector metadata (10.0%) and relay envelopes (2.8%):** transport fields must not be mistaken for weather.
12. **Forecast/trend groups (7.4%):** TEMPO and BECMG values must not overwrite observed weather.
13. **Late delivery after an outage (4.9%):** the report's day-of-month must be reconciled with receipt context.
14. **Local-time envelopes (5.0%):** normalize the envelope timestamp to UTC before using it as date context.
15. **Fractional statute miles (4.8%):** for example, \`1 1/2SM\`.
16. **Cloud suffixes (3.8%) and vertical visibility (1.3%):** CB/TCU suffixes and VV groups still affect ceiling.
17. **O-for-0 typing errors (1.3%):** examples include \`A3O01\` and \`BKNO15\`.
18. **Corrections and duplicate delivery (7.5% and 4.0%):** the final copy for a key must win.
19. **Missing sensor groups (3.1%):** absent fields must not shift later values into the wrong output columns.
20. **Hour 2400 (0.2%):** midnight may be represented as hour 24 on the day that is ending.

The conditions overlap. A single record may have a bulletin prefix, lower-case text, a missing Z, and a split body at the same time.

## 5. Data-engineering concepts exercised

| Concept | Why it matters here |
|---|---|
| Streaming state machine | A report may continue on the next input line; the handler must retain pending state |
| Natural/business key | \`(station, observed_at)\` identifies an observation independently of its transport record |
| Last-write-wins | A corrected report replaces the earlier version without creating a duplicate output |
| Idempotency and replay handling | Replayed collector files must not produce extra rows |
| Semi-structured data normalization | JSON aliases, nested envelopes, and changing key order require robust extraction |
| Text parsing and canonicalization | Hand-entered variations should be normalized before field extraction |
| Event-time reconstruction | Day-only observation timestamps need receipt/archive context to recover month and year |
| Time-zone normalization | Local collector timestamps must be converted to UTC |
| Unit conversion | Wind, visibility, and pressure arrive in different units |
| Domain-aware parsing | CAVOK, VV, cloud layers, remarks, and forecast groups have specific meanings |
| Data quality and observability | Unknown formats and rejected rows should be counted and sampled |

## 6. Difficulty and experience-equivalent estimate

| Artifact | Estimated level | Heuristic experience-equivalent range | Rationale |
|---|---|---:|---|
| Problem requirements | Hard (4/5) | 4–6 years | Many interacting formats, domain rules, stream state, correction semantics, and date rollover |
| Current \`handler.py\` | Intermediate–Hard | 3–4 years | Strong JSON recovery, aliases, timestamp normalization, Decimal conversion, and field extractors; however, it emits revised keys early and lacks continuation buffering |
| Reference \`gold_submit.py\` | Advanced | 5–7 years | Stateful pending-line logic, bulletin/archive handling, broader METAR tokenization, and final last-write-wins output |

These are heuristic skill-equivalence estimates based on the scope and implementation patterns visible in this one challenge. They are not a measurement of anyone's actual employment history, seniority, or hiring readiness. Confidence is medium because the estimates are qualitative and the hidden dataset cannot be inspected.

## 7. Common implementation traps

- Returning rows from \`process()\` before a later correction can arrive.
- Returning an empty list from \`finalize()\` even though the stream may have changed earlier rows.
- Treating the first four-letter token as the airport without removing a bulletin heading.
- Requiring every observation time to end in Z.
- Passing hour 24 directly to a datetime constructor instead of rolling it to the next day.
- Parsing one whitespace token at a time when a manually typed group may be split across tokens.
- Scanning the whole report and accidentally reading TEMPO/BECMG forecast values as observed conditions.
- Treating runway visual range as horizontal visibility.
- Cleaning leading whitespace before checking whether a line is a continuation.
- Assuming the receipt date is always the observation date.
- Converting numeric values without preserving the required output type and decimal precision.

## 8. Learning path

1. **Learn the METAR groups.** Understand station/time, wind, visibility, cloud layers, temperature/dew point, pressure, remarks, and trend groups.
2. **Define the observation key and output contract.** Make one row per \`(station, observed_at)\` a hard invariant.
3. **Fix stream semantics first.** Buffer the latest row per key and emit only from \`finalize()\`.
4. **Add continuation buffering.** Hold an unfinished report until the next line confirms whether it continues.
5. **Normalize wrappers and text.** Remove bulletin/archive prefixes, normalize case and whitespace, and join documented split groups.
6. **Parse time and units.** Handle UTC offsets, day/month/year rollover, no-Z times, hour 2400, and unit conversions.
7. **Add field-specific tests.** Validate observation-versus-forecast boundaries and every supported representation.
8. **Measure condition-level recovery.** A good overall score can hide a parser that completely misses one less-common but important input family.

## 9. Interview questions

1. Why is \`(station, observed_at)\` a better key than the raw JSON line or a collector sequence number?
2. How would you implement last-write-wins when corrections can arrive after the original report?
3. Why should a streaming handler sometimes return no rows from \`process()\` and emit only in \`finalize()\`?
4. How would you detect and safely join a continuation line without accidentally joining the next airport's report?
5. How would you reconstruct a UTC timestamp when the report contains only day-of-month and time?
6. How should \`312400Z\` be interpreted, and what happens at the end of December?
7. How would you prevent TEMPO/BECMG forecast values from replacing the observed weather?
8. What tests would prove that an identical replay is idempotent and a corrected replay replaces the earlier row?
9. How would you monitor unknown METAR formats and distinguish malformed input from an unsupported parser rule?

## 10. Companion analysis

See [GPT_Analysis.md](./GPT_Analysis.md) for the code-level comparison between \`handler.py\` and \`gold_submit.py\`, the scorecard, prioritized findings, recommended changes, and validation scenarios.

