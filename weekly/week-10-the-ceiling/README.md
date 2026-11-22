# Week 10: The Ceiling

*Every airport on earth reports its weather in a code built for teletypes. An airline needs 4 days of it as a table.*

[The Gauntlet on DataDriven](https://datadriven.io/community/week-10)

You're a data engineer at an airline. Every airport reports its weather about once an hour as a METAR, a short line of code that pilots read. Collectors logged each METAR as 1 JSON line, and the dispatch team needs 1 clean row per report to study the delays around New Year. Write the code that turns the log into that table.

## Result

| | |
|---|---|
| Score | 0.8185 |
| Rank | #4 of 6, top 67% |
| Points | +20 |
| Records recovered | 801,178 of 855,838 |
| Work per record | 1.4x median |
| Statements | 468 |
| Scored | 2026-11-22 |

60,340 rows were a second row for a key already emitted and 9,855 rows matched no record. Together they cost 140,390 points.

## Columns

| Column | Correct | Wrong | Missed |
|---|---:|---:|---:|
| `altimeter_hpa` | 78% | 2,418 | 187,860 |
| `visibility_m` | 78% | 38,436 | 148,675 |
| `wind_kt` | 80% | 5,233 | 163,334 |
| `temp_c` | 84% | 23,168 | 112,116 |
| `ceiling_ft` | 91% | 6,846 | 73,676 |
| `station` | 94% | 0 | 54,660 |
| `observed_at` | 94% | 0 | 54,660 |

## What the stream held

Every condition in the data, ordered by what it cost. "Handled" means its records came through about as well as the rest of the run.

| Condition | Of stream | Recovered | Handled |
|---|---:|---:|:---:|
| A value typed in 2 parts | 17.2% | 68% | no |
| KTS, KM, QNH: units by hand | 15.9% | 68% | no |
| Key order changes | 30.0% | 85% | yes |
| A time with no Z | 2.9% | 0% | no |
| A bulletin heading in front | 4.0% | 32% | no |
| Readings below zero | 13.8% | 84% | yes |
| Minus signs and loose digits | 6.5% | 72% | no |
| CAVOK in place of numbers | 12.6% | 87% | yes |
| An = at the end | 12.0% | 85% | yes |
| Split over 2 log lines | 6.0% | 70% | no |
| Wind in m/s | 7.4% | 82% | no |
| Collector bookkeeping fields | 10.0% | 85% | yes |
| NDV and runway range | 8.0% | 83% | yes |
| TEMPO and BECMG outlooks | 7.4% | 84% | yes |
| Sent late, after an outage | 4.9% | 85% | yes |
| A date line or a tag kept | 4.0% | 80% | no |
| Local time on the envelope | 5.0% | 85% | yes |
| A line break in the middle | 5.0% | 86% | yes |
| Miles with a fraction | 4.8% | 87% | yes |
| CB or TCU on a layer | 3.8% | 84% | yes |
| An O typed for a zero | 1.3% | 61% | no |
| Sent again with a fix | 7.5% | 83% | yes |
| The relay's own line format | 2.8% | 85% | yes |
| The same line sent twice | 4.0% | 86% | yes |
| The line in lower case | 3.0% | 85% | yes |
| Sensors out, parts absent | 3.1% | 92% | yes |
| VV: a sky no one can see | 1.3% | 84% | yes |
| Midnight as hour 2400 | 0.2% | 0% | no |

### Why these happen

**A value typed in 2 parts.** Typed by hand, a group comes apart: 30007 KT, 180/12KT, 10 SM, BKN 015, 22 / 14, A 3001. A reader that takes 1 group per space sees a number with no unit and a unit with no number, and the 3001 after a lone A looks like a visibility.

**KTS, KM, QNH: units by hand.** A small airport's observer types the report from a paper form, the same way every day: 18012KTS, CALM for no wind, 10KM or 2000M for the visibility, QNH1013 or 1013HPA or A30.01 for the altimeter, or the 4 digits alone after the temperature, where 3001 can only be inches and 1013 only hectopascals. None of it is in the code manual, and all of it says exactly 1 thing.

**Key order changes.** JSON objects are unordered, and every collector builds them from a map. Key order carries no meaning and should never be relied on.

**A time with no Z.** The Z after the time says UTC, and every report is in UTC, so some observers leave it off or spell it out: 311851, 311851UTC. A reader that finds the time by its Z finds no report at all.

**A bulletin heading in front.** Reports cross the network in bulletins whose first line names the data type, the compiling center and a time: SAUS70 KWBC 311900. A collector that keeps that line puts a 4 letter center and a 6 digit time ahead of the station's own.

**Readings below zero.** The code has no minus sign. The body writes M05 for minus 5, and the US remarks carry tenths behind a sign digit: T10501106 is minus 5.0 with a dew point of minus 10.6. Read as a plain number, that group is 105 degrees.

**Minus signs and loose digits.** The code writes minus 5 as M05, and an observer typing by hand writes -05, or M5, or 5/M1 with no leading zeros, or the thermometer's own tenths: 22.4/14.1.

**CAVOK in place of numbers.** When visibility is 10 km or more with no cloud below 5,000 feet and no weather, ICAO stations write the single word CAVOK and leave out the visibility and cloud groups. The visibility is the code's top value and there is no ceiling.

**An = at the end.** On the wire a report ends with an equals sign, and some collectors keep it. It rides on the last group, or after a space.

**Split over 2 log lines.** A collector that reads its circuit a line at a time logs a wrapped report as 2 lines: the first ends mid-report, and the next starts with spaces and has no station or time of its own. The second line belongs to the first, and the row is not whole until both are read.

**Wind in m/s.** Russia, China and a few of their neighbours report wind in meters per second, and the group ends in MPS. The digits look the same as knots and are about half the value.

**Collector bookkeeping fields.** Collectors add their own circuit, sequence and host markers. They describe how the report travelled, not the weather, and do not belong in the table.

**NDV and runway range.** Visibility brings company: NDV on an automated sensor that cannot tell direction, a second lower value with a compass point, and runway visual range groups such as R27L/0800 that hold 4 digits of their own. Only the first plain value is the visibility.

**TEMPO and BECMG outlooks.** Many stations outside North America append a 2 hour outlook to the observation: TEMPO or BECMG, then wind, visibility and cloud in the same forms as the observation. A reader that scans the whole line takes the forecast for the weather.

**Sent late, after an outage.** A station that loses its link keeps observing and sends the backlog when the link returns. A report states only its day of the month, so one logged on 1 January with day 31 belongs to December of the year before, and reading the month and year off the log stamp misplaces it.

**A date line or a tag kept.** Some collectors read public archives instead of the circuit, and each archive wraps a report its own way: a line with the date above it, the station and time in front as comma separated values, a raw_text tag around it. The report inside is untouched.

**Local time on the envelope.** Some collector hosts stamp lines in their own time zone with its offset. Near midnight the local date is a different day, month or year from the report's UTC day, so the stamp has to be brought to UTC before it can date a report.

**A line break in the middle.** The circuits that carry these reports wrap at 69 characters and indent the rest. A collector that keeps the wrap leaves a line break and spaces inside the report, sometimes between the 2 halves of a mixed number.

**Miles with a fraction.** US and Canadian observers report visibility in statute miles off a chart marked in quarters, so low values are fractions, and a value like 1 1/2SM is 2 space separated groups. Read alone, the 1/2SM is a third of the truth and the stray 1 shifts everything after it.

**CB or TCU on a layer.** A layer of thunderstorm cloud is flagged on the group itself: BKN015CB, OVC008TCU. A pattern that expects 3 letters and 3 digits skips the layer that sets the ceiling.

**An O typed for a zero.** On a keyboard the letter O sits beside the zero, and in a group that can only hold digits the 2 are the same slip: A3O01, BKNO15, 1OSM, 18O12KT.

**Sent again with a fix.** A replay can also bring the first copy of a report back after the copy that fixed it. The copy logged last still stands.

**The relay's own line format.** Some airports reach the log only through an older relay collector built by another team. It writes src where the main collectors write feed, a ts that is epoch seconds or a compact stamp, and the report 1 level down, under msg. The report inside is the same code.

**The same line sent twice.** The older relay covers some of the same airports as the main collectors and writes the report its own way, and a collector that restarts sends a file again hours later. The identity of a report is its airport and its observation time, never the line it came in.

**The line in lower case.** One collector's store folds text to lower case for searching. The code is upper case by convention only: metar egll 300120z 34005kt reads the same.

**Sensors out, parts absent.** An automated station with a failed sensor still reports. US stations drop the group and note the sensor in the remarks, ICAO stations write slashes in its place, and a station with nothing to send writes NIL. A reader that counts positions puts every later group in the wrong column.

**VV: a sky no one can see.** In fog the observer cannot see a cloud base, so the report gives vertical visibility: VV002 is 200 feet. Aviation counts that as the ceiling, the same as a broken or overcast layer.

**Midnight as hour 2400.** Some stations log the midnight observation as hour 24 of the day that is ending: 312400Z is the first minute of the 1st. A date library rejects hour 24, and on 31 December the day that follows is in another year.

Concepts exercised: pyArithmetic, pyBooleanOps, pyBreakContinue, pyClassBasic, pyCsvJson, pyDataTypes, pyDictComprehension, pyDictCreate, pyDictIterate, pyDictMerge, pyDictMethods, pyDictNested, pyDunderMethods, pyEnumerate, pyExceptionTypes, pyFStrings, pyForBasic, pyFuncDef, pyFuncDefault, pyGuardClauses, pyIfElse, pyJsonHandling, pyLambda, pyListComprehension, pyListCopy, pyListCreate, pyListModify, pyListSort, pyMathOps, pyModules, pyNestedLoops, pyRecursion, pyRegex, pySetOperations, pySets, pySlicing, pyStringBasic, pyStringFormat, pyStringIndex, pyStringMethods, pyStringSplitJoin, pyTernary, pyTryExcept, pyTuples, pyTypeConversion, pyUnpacking, pyVariables, pyWhileLoops

## Submission

The handler that was graded is in [`handler.py`](./handler.py).
