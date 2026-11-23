---
week: 10
folder: week-10-the-ceiling
title: The Ceiling
format: python
domain: Aviation / Airline operations - METAR weather reports
difficulty: 4
yoe_problem: 5-7
yoe_you: 3-5 (medium)
yoe_gold: 5-8
confidence_you: medium
score: 0.8185
rank: 4/6
analysis: yes
---

# Week 10: The Ceiling - Problem overview

Python handler · score 0.8185, rank #4 of 6 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

An airline's dispatch team wants to study the delays around New Year, and the only source is a log of weather reports. Every airport reports about once an hour as a **METAR**, a short line of code that pilots read (`METAR EGLL 311850Z 34005KT 9999 BKN015 M05/M10 Q1013=`). Collectors logged each one as 1 JSON line. You write a `Handler` that turns the log into **1 clean row per report**: station, observation time, wind in knots, visibility in metres, ceiling in feet, temperature and altimeter in hPa. The hard part: the code is written by hand at small airports, wrapped by old circuits, wrapped again by bulletins and collectors, and each of the 28 conditions in the README changes the text in a different way. The identity of a row is the airport and the observation time, never the line it came in.

## 2. Domain and real-world context

**Aviation weather data.** METAR is the worldwide standard for airport weather. Airlines, dispatch and flight-planning tools parse it every day, and the same few traps appear everywhere: units that differ by country (knots, m/s, statute miles, inches of mercury), no minus sign in the code, a "ceiling" defined by the lowest broken or overcast layer, and reports that are corrected or sent again. In real life this is the job of data engineers who build weather feeds for operations control: normalize free text from many collectors, decide which copy of a report is final, and keep the data trustworthy for delay analysis.

## 3. Difficulty: 4/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 28 `[measured]` |
| Lines of code | 698 in your `handler.py`, 446 in the gold `[measured]` |
| Output columns | 7 (`station`, `observed_at`, `wind_kt`, `visibility_m`, `ceiling_ft`, `temp_c`, `altimeter_hpa`) `[measured]` |
| Recoverable records | 855,838 `[measured]` |
| Hard constraints | 1 row per `(station, observed_at)`; each extra row for a key already emitted costs points; a row with no matching record costs points `[measured]` |
| Hidden requirement | do not emit early: hold the last copy of each report, and hold a report until the next line shows whether it was wrapped `[inferred]` |

Why 4: the individual conditions are small, but there are many of them and they overlap (a bulletin heading plus a lower-case line plus a wrapped second half). It needs domain knowledge (what `M05`, `CAVOK`, `VV002`, `T10501106` mean), month and year inference near New Year, and a state rule for the last copy. It is not a 5 because it has no history model and no join: the solution is a careful text parser with 1 small state machine.

## 4. Problems the data throws at you

1. **Values typed in 2 parts.** `30007 KT`, `180/12KT`, `10 SM`, `BKN 015`, `22 / 14`, `A 3001` (17.2% of the stream). Hard because 1 group per space sees a unit with no number.
2. **Units by hand.** `KTS`, `CALM`, `10KM`, `QNH1013`, `1013HPA`, `A30.01`, or 4 bare digits after the temperature (15.9%).
3. **Time and date.** A time with no Z (2.9%), midnight written as `2400` (0.2%), reports sent late with day 31 on 1 January (4.9%), local time on the envelope (5.0%).
4. **Text around the report.** A bulletin heading `SAUS70 KWBC 311900` (4.0%), an `=` at the end (12.0%), a date line or a tag kept (4.0%), a line in lower case (3.0%), a line break in the middle (5.0%).
5. **A report over 2 log lines.** The second line starts with spaces and has no station (6.0%).
6. **Numbers below zero.** `M05`, `-05`, `M5`, `5/M1`, tenths `22.4/14.1`, the US remark `T10501106` (13.8% + 6.5%).
7. **Visibility and sky.** `CAVOK` (12.6%), `NDV` and runway range `R27L/0800` (8.0%), fractions in miles `1 1/2SM` (4.8%), `CB`/`TCU` on a layer (3.8%), `VV002` (1.3%), an O typed for a zero (1.3%).
8. **Other wind and forecast.** Wind in `MPS` (7.4%), a `TEMPO` or `BECMG` outlook after the observation (7.4%).
9. **Duplicates and relays.** Sent again with a fix (7.5%), the same line twice (4.0%), the relay's own format with `src`, `ts`, `msg` (2.8%), sensors out and `NIL` (3.1%).

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Normalize once, parse after | Rewrite every hand-typed form to one standard form at the door, then use simple extractors | `data normalization`, `canonicalization`, `preprocessing` |
| Last-write-wins state | Keep the last copy of each key and emit once at the end | `idempotent load`, `upsert`, `at-least-once delivery` |
| Natural key | `(station, observed_at)` identifies a report, not the line | `natural key`, `deduplication`, `entity resolution` |
| Buffering a record across lines | A wrapped report is whole only after the next line is read | `line continuation`, `stateful stream processing`, `sessionization` |
| Defensive parsing | A bad group gives `None`, not a failed run | `try/except`, `regex anchors`, `fail-safe parsing` |
| Time inference | The day of the month plus the log stamp gives the month and year | `date inference`, `year rollover`, `UTC normalization` |
| Unit conversion | Knots, m/s, statute miles, inches of mercury, hPa | `unit conversion`, `Decimal rounding`, `half-up` |
| Domain code (METAR) | `M05` is minus 5, `VV` counts as the ceiling, `CAVOK` means 9999 and no ceiling | `METAR format`, `ICAO Annex 3` |

A short example of the "normalize once" rule: glue a split group back together before any extractor runs.
```python
t = re.sub(r"\b((?:\d{3}|VRB)\d{2,3}(?:G\d{2,3})?) (KTS?|MPS|KMH)\b", r"\1\2", t)   # 30007 KT -> 30007KT
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **5-7 years** | medium | 28 interacting text conditions, domain knowledge of METAR, last-copy semantics, year rollover, wrapped lines |
| Your code (`handler.py`) | **3-5 years** | medium | alias lookup and `flatten` for nested and relay lines (L8-21, L173-216), nested JSON strings unwrapped (L151-159), TEMPO/BECMG cut before scanning (L391-433), Decimal-safe rounding; but each row is emitted again when its values change (L660-672) and `finalize()` returns `[]` (L697-698) |
| Gold code (`gold_submit.py`) | **5-8 years** | medium | bulletin heading removed before reading the station (`_BULLETIN` L19-23, `_header` L109-139), typed forms accepted in one place (`_WIND` L25, `_pressure` L189-206), wrapped lines joined with `pending` (L356-373, L378-379), nothing emitted until `finalize()` (L427-446) |

- `handler.py` has a good extraction core. The gap to the gold is **when it emits** (once, at the end) and **how forgiving the text rules are** (typed forms, heading, missing Z).
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined against platform feedback, and it has blind spots of its own (for example it ignores the relay's `msg` line, L322-324 `[inferred]`).

## 7. Common traps

- **Emitting early.** Sign: `out.append(row)` in `process()` for a key that can be resent with a fix.
- **Reading the first 4-letter token as the station.** Sign: a loop that returns the first `[A-Z]{4}` before the time, with no step that removes a bulletin heading.
- **A time that must end in `Z`.** Sign: `\d{6}Z` as the only way to find the observation.
- **1 group per space.** Sign: `token.split()` followed by `fullmatch` on `\d{3}\d{2}KT`, with no glue step for `30007 KT`.
- **Any 4-5 digits are visibility.** Sign: `re.fullmatch(r"\d{4,5}", token)` with no check that the token is before the temperature.
- **Strict number shape for temperature.** Sign: `(M?\d{2})/(M?\d{2})` on a line that may hold `-5/-10`.
- **Whitespace cleaned before it is used.** Sign: `strip()` in a cleaner that runs before the check "does this line start with spaces?".
- **Month and year from the log stamp.** Sign: `received_at.month` used without comparing the report's day.

## 8. Mindset difference (you vs gold)

Your file extracts each field well and tries to be correct at every line. The gold **decides late**: it holds the last copy of every report and the unfinished report at the end of the line, and makes the text standard before it reads it. Your `process()` emits again when a value changes, so a corrected report becomes 2 rows, and 60,340 rows were a second row for a key already emitted. A bulletin heading with no `METAR` word is read as station `KWBC`, which fits the 9,855 rows that matched no record `[inferred]`. The specific lines, the Before/After code and the checklist are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** A collector resends a report with a fix, and the corrected copy is logged after the first one. Which row do you emit, and when? *Hint: the last copy logged stands; emit once at the end, keyed by station and observation time.*
2. **(mid)** The temperature group is `M05/M10`. What are the two values? *Hint: `M` is a minus sign; the code has none.*
3. **(mid)** Wind is `34005MPS` at a Russian airport. What is `wind_kt`? *Hint: convert m/s to knots (x 3600 / 1852) and round half up.*
4. **(senior)** A line has spaces first and no station. What is it, and how do you handle it? *Hint: the second half of a wrapped report; hold the previous report until the next line shows it is whole.*
5. **(senior)** A report on 1 January says day 31. Which month and year? *Hint: choose the month nearest the log stamp that makes the day valid.*
6. **(senior)** `3001` appears after the temperature with no letter. Visibility or altimeter? *Hint: by range: 2800-3200 is inches of mercury, 850-1100 is hPa.*
7. **(mid)** The line is `SAUS70 KWBC 311900 KJFK 311853Z ...`. What is the station? *Hint: remove the bulletin heading first.*

## 10. Learning path

**Order of study:** (1) METAR groups and what each means → (2) normalize the text once → (3) last-copy state and emit at the end → (4) buffer a wrapped report → (5) dates near a month or year boundary.

**Exercise 1 - Typed forms (30-45 min).** Write 12 spellings of the same wind, visibility and altimeter (`30007 KT`, `180/12KT`, `18012KTS`, `10 SM`, `QNH1013`, `A30.01`...). Write `tidy(text)` that makes each one standard. *Self-check:* all 12 give the same row.

**Exercise 2 - Resent with a fix (30 min).** Feed the same key 3 times with different wind. *Self-check:* the output has 1 row with the last wind, and feeding the file twice changes nothing.

**Exercise 3 - Wrapped line (45 min).** Feed a report cut into 2 lines, the second starting with spaces. *Self-check:* 1 row with all fields; a report with no second line is still emitted at the end.

**Exercise 4 - Heading and time (30 min).** Feed `SAUS70 KWBC 311900 KJFK 311853Z ...` and `... EGLL 311851 ...`. *Self-check:* stations `KJFK` and `EGLL`, observation times with Z.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 10](https://datadriven.io/community/week-10)
