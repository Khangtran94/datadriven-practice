# Week 10 – The Ceiling: Review of \`handler.py\` Against \`gold_submit.py\`

## 1. Challenge result

Week 10 is a stateful Python parsing challenge. The handler must turn noisy JSON-wrapped METAR observations into one row per airport observation, keyed by \`(station, observed_at)\`.

| Metric | Result |
|---|---:|
| Score | 0.8185 |
| Rank | #4 of 6 (top 67%) |
| Points | +20 |
| Records recovered | 801,178 / 855,838 |
| Work per record | 1.4× median |
| Statements | 468 |
| Scored | 2026-11-22 |

The README reports 60,340 rows that were a second row for a key already emitted and 9,855 rows that matched no record. Together, these cost 140,390 points. The duplicate-row penalty is the largest measured issue; the unmatched rows are a second, separate problem.

### Output-column scorecard

| Output | Correct | Wrong | Missed | Main interpretation |
|---|---:|---:|---:|---|
| \`altimeter_hpa\` | 78% | 2,418 | 187,860 | Large coverage gap plus hand-typed pressure formats |
| \`visibility_m\` | 78% | 38,436 | 148,675 | Visibility variants, split groups, and token boundaries |
| \`wind_kt\` | 80% | 5,233 | 163,334 | Wind format/unit variants and records not fully parsed |
| \`temp_c\` | 84% | 23,168 | 112,116 | Negative, shortened, decimal, and split temperature groups |
| \`ceiling_ft\` | 91% | 6,846 | 73,676 | Separated cloud groups and less common ceiling forms |
| \`station\` | 94% | 0 | 54,660 | Rows not emitted or station misidentified |
| \`observed_at\` | 94% | 0 | 54,660 | Rows not emitted or observation time not recovered |

“Wrong” means a value was emitted but did not match the expected value. “Missed” means the expected value was absent. The equal missed count for \`station\` and \`observed_at\` is consistent with whole records being omitted rather than two independent field parsers failing.

## 2. The most important architectural issue: emitting before the stream is complete

### Evidence in \`handler.py\`

The current \`Handler.process()\` stores packed values in \`self.records_map\`, but it also appends a row to the return value whenever the values for an existing key change:

\`\`\`python
values = _pack_record(row)
if self.records_map.get(key) == values:
    continue
self.records_map[key] = values
out.append(row)
return out
\`\`\`

The current \`finalize()\` returns an empty list:

\`\`\`python
def finalize(self):
    return []
\`\`\`

This is incompatible with the README's correction rule: a report can be sent again with a fix, and the copy logged last stands. The first version may already have been emitted before the correction arrives. Updating the dictionary does not retract the earlier output row.

The code already has useful building blocks: \`_record_key()\`, \`_pack_record()\`, \`_unpack_record()\`, and \`extract_columns()\`. The helper \`deduplicate_records()\` also exists, but the main \`Handler.process()\` path does not use it to enforce one final output row per key.

### Recommended change

Keep the latest values in memory, return no rows from \`process()\`, and emit the unique map once from \`finalize()\`.

\`\`\`python
def process(self, raw):
    # Normalize and extract as today.
    # For every valid key:
    self.records_map[key] = _pack_record(row)
    return []

def finalize(self):
    return [
        _unpack_record(key, values)
        for key, values in self.records_map.items()
    ]
\`\`\`

This is a design sketch, not a tested replacement for the complete handler. Preserve the existing exception handling and row validation when applying it.

**Why this is first priority:** it directly addresses the largest measured penalty category (60,340 second rows). The same principle applies to identical retries and corrected replays: the final state is keyed by the business identity, not by the number of input lines.

## 3. Unmatched rows: remove bulletin metadata before identifying the airport

### Evidence in \`handler.py\`

\`extract_station()\` first looks for a station after an explicit \`METAR\` or \`SPECI\` token. If that fails, it returns the first four-letter ICAO-looking token before a \`DDHHMMZ\` time.

That fallback can mistake a bulletin originator for the airport. For example:

\`\`\`text
SAUS70 KWBC 311900 KJFK 311853Z 18012KT ...
\`\`\`

Here \`KWBC\` is part of the bulletin heading; \`KJFK\` is the station. If the heading is not removed first, the parser can construct a plausible but incorrect key. This is a strong code-based explanation for at least some unmatched rows, but the README does not attribute every one of the 9,855 unmatched rows to this single cause.

### Reference behavior

\`gold_submit.py\` defines \`_BULLETIN\` and removes a matching bulletin prefix in \`_header()\` before extracting station and time. It also recognizes an archive date line before parsing the METAR header.

### Recommended change

Introduce a header-cleaning stage before both station and observation-time extraction. It should recognize the documented bulletin form and archive wrapper, while preserving the original report for diagnostics.

Do not solve this by simply taking the first four-letter token. The first ICAO-shaped token is not necessarily the observing station.

## 4. Parsing gaps by output field

### 4.1 Wind

**Current behavior:** \`WIND_RE\` accepts a compact direction/speed group and the units \`KT\`, \`MPS\`, or \`KMH\`. It does not accept the common hand-entered \`KTS\` spelling or separated/two-part forms such as \`30007 KT\` and \`180/12KT\`.

**Reference behavior:** \`_WIND\` accepts \`KTS\` and additional variants; \`_legacy_field()\` also recognizes named legacy fields. The reference converts m/s and km/h to knots with integer ratio arithmetic.

**Recommendation:** normalize common spacing and unit aliases before extracting wind. Keep gust speed separate from mean speed: the output asks for the sustained/mean wind, not the gust. Validate conversion and rounding at boundaries rather than relying on binary floating-point.

### 4.2 Visibility

**Current behavior:** the parser recognizes CAVOK, plain 4–5 digit values after the observation time, and statute-mile forms including mixed and fractional miles. It stops the ordinary token scan at \`RMK\`, \`NOSIG\`, \`TEMPO\`, or \`BECMG\`.

Important gaps include \`10 SM\` (two tokens), \`10KM\`, \`9999NDV\`, and cases where a separated group or a forecast value is accidentally considered by a broad fallback regex. The current \`MIXED_SM_RE\`, \`FRACTION_SM_RE\`, and \`INTEGER_SM_RE\` search the full text, so they deserve explicit tests for forecast/remark contamination.

**Reference behavior:** \`_surface_visibility()\` handles fractional statute miles, a preceding whole-mile token, and metre groups with \`NDV\`/unit suffixes. It caps the output at 9999 m.

**Recommendation:** parse the observation body only, stop at forecast/remark boundaries, and join documented two-part visibility forms before conversion. Keep runway visual-range groups (for example \`R27L/0800\`) out of the surface-visibility field.

### 4.3 Ceiling

**Current behavior:** \`extract_ceiling_ft()\` finds \`BKN\`, \`OVC\`, and \`VV\` groups and chooses the lowest height. It accepts a cloud-type suffix, which helps with \`CB\` and \`TCU\`.

It does not join a separated group such as \`BKN 015\`. It also needs tests that prove forecast groups after \`TEMPO\`/\`BECMG\` do not replace the observed ceiling.

**Reference behavior:** \`_CLOUD\` accepts cloud suffixes including \`CB\`, \`TCU\`, and slash placeholders; the weather parser ignores trend groups after the trend marker.

**Recommendation:** normalize split cloud tokens before parsing and retain the “lowest BKN/OVC/VV layer” rule. Do not treat FEW or SCT as a ceiling.

### 4.4 Temperature

**Current behavior:** the standard temperature regex accepts only two-digit \`M?\d{2}/M?\d{2}\` groups. This misses hand-entered negative signs, shortened values such as \`M5/M1\`, separated groups such as \`22 / 14\`, and decimal readings such as \`22.4/14.1\`.

The remarks parser recognizes the precise \`T\` tenths form, which is a useful strength. However, a report can contain both a rounded main temperature and a more precise remark; the chosen precedence should be explicitly tested.

**Reference behavior:** \`_TEMP\` accepts signed, M-prefixed, and decimal values. \`_TENTHS\` decodes the remarks form, and the parser prefers that precise value when available.

**Recommendation:** parse signed/decimal forms using a decimal-safe helper and document the precedence between the main group and the remarks value. Avoid converting a temperature by stripping every non-digit character.

### 4.5 Altimeter

**Current behavior:** the parser accepts compact \`A####\` and \`Q####\` groups, with range checks, and returns a one-decimal string. It does not accept forms such as \`A 3001\`, \`A30.01\`, \`QNH1013\`, or \`1013HPA\`.

**Reference behavior:** \`_pressure()\` supports the standard A/Q groups, while \`_ALTIMETER_TYPED\` and \`_legacy_field()\` cover several hand-entered forms.

**Recommendation:** support documented typed forms and distinguish inches of mercury from hectopascals by explicit prefix/unit or a defensible range rule. Preserve the output contract: a string with exactly one decimal place, not a float and not an integer.

## 5. Time reconstruction and stream context

### What the current code already does well

- \`clean_timestamp()\` accepts ISO timestamps, numeric epoch seconds/milliseconds/microseconds, and timestamps with offsets; offset-aware values are normalized to UTC.
- \`extract_observed_at()\` tries the observation day in the received timestamp's previous/current/next month and chooses the closest valid candidate.
- This nearest-month approach is appropriate for the documented short late-arrival window around New Year, including a day-31 observation received on 1 January.

### Remaining gaps

1. **Missing Z:** both \`OBSERVATION_TIME_RE\` and \`extract_observed_at()\` require the literal \`Z\`. The README says some reports omit it or use \`UTC\`. The reference header pattern makes Z optional.
2. **Hour 2400:** the current code rejects hour 24. Importantly, the checked-in \`gold_submit.py\` also rejects it: \`_header()\` explicitly returns \`None\` when \`hour > "23"\`. This is a known gap in both implementations, not a reference advantage. Correct handling must roll \`DD2400\` forward to midnight on the next calendar day, including month/year rollover.
3. **Archive date context:** the current parser does not extract an archive date line as a separate date anchor. The reference recognizes one and uses it when reconstructing a day-only timestamp.
4. **Local envelope timestamps:** the current offset normalization is a strength, but tests should confirm that the local envelope is converted to UTC before selecting the observation month.

A safe implementation should parse the report header into a structured day/hour/minute first, derive the full date using archive/receipt context, and only then construct the UTC timestamp. Do not try to repair hour 24 by passing it directly to \`datetime()\`.

## 6. Split reports and stateful processing

The README says some reports are split over two log lines, with the continuation beginning in whitespace and carrying no station/time of its own.

The current \`Handler\` has no pending-report buffer. It normalizes each input independently, so the continuation cannot reliably be associated with the preceding report. It may emit a partial row from the first half and discard the second half.

The reference uses \`self.pending\`, \`_continued_body()\`, and \`_same_circuit()\` to hold an unfinished report and decide whether the next line belongs to it. It flushes the pending report when a new header arrives or the stream ends.

**Recommendation:** introduce a small state machine:
- Hold the current report until the next input establishes whether it is complete or continued.
- Join a continuation only when the circuit/receipt context is compatible and the tail resembles a valid METAR continuation.
- Flush pending content before starting a new report and during \`finalize()\`.
- Feed the completed report through the same normalization and extraction path as an unsplit report.

The pending buffer and last-write-wins map solve different problems. Both are needed: one reconstructs a complete report; the other chooses the final version for a report key.

## 7. Strengths worth preserving

- Broad JSON recovery: nested JSON strings, arrays, wrapper keys (\`rows\`, \`records\`, \`items\`, \`messages\`), and salvage of complete fields from damaged JSON.
- Flexible key normalization and aliases, including nested paths and relay-style \`msg\`/\`ts\` fields. This is broader than the checked-in reference's \`_record()\`, which looks for a narrower set of report keys.
- Timestamp normalization for ISO, epoch, and offset-aware inputs.
- Decimal-based statute-mile conversion and half-up rounding.
- CAVOK handling and the lowest broken/overcast/vertical-visibility ceiling rule.
- Trend/remark boundaries in several field extractors.
- A compact packed-value representation for keyed records.

Do not replace these strengths with a wholesale copy of the reference. Port the missing behavior while preserving the more flexible JSON envelope handling.

## 8. Priority order

| Priority | Change | Evidence / expected impact |
|---|---|---|
| 1 | Defer all output until \`finalize()\`; last-write-wins by \`(station, observed_at)\` | Directly targets the 60,340 measured second rows |
| 2 | Strip bulletin/archive wrappers before station/time extraction | Strong explanation for some unmatched keys; verify against targeted samples |
| 3 | Add a pending buffer for split reports | README says this condition is 6.0% of the stream; current handler has no cross-call continuation state |
| 4 | Accept missing-Z / UTC time forms | README condition recovery is 0%; current regex requires Z |
| 5 | Normalize two-part and hand-typed wind/visibility/cloud/temperature/pressure groups | Multiple high-frequency conditions have low recovery |
| 6 | Handle hour 2400 and date rollover | Explicit README condition; both current and reference code reject hour 24 |
| 7 | Add diagnostics for unknown forms and per-condition recovery | Helps distinguish malformed source from parser coverage gaps |

## 9. Validation plan

The following are recommended tests derived from the README and source code. They are not claimed to have been run against the hidden dataset.

| Validation Scenario | Test Input | Expected Result |
|---|---|---|
| Corrected report | Same station/time twice with different wind values | One final row; the later report's values win |
| Identical replay | Same report delivered twice | One final row; no duplicate output |
| Bulletin prefix | \`SAUS70 KWBC 311900 KJFK 311853Z ...\` | Station is \`KJFK\`, not \`KWBC\` |
| Missing Z | \`METAR EGLL 311851 18012KT ...\` | Observation time is reconstructed in UTC |
| UTC suffix | \`METAR EGLL 311851UTC ...\` | Same observation time as the equivalent Z form |
| Hour 2400 | \`METAR EGLL 312400Z ...\` | Midnight on the following calendar day |
| Split report | First line ends after \`BKN\`; next line begins \`015 15/10 Q1013=\` | One complete row with ceiling, temperature, and pressure |
| Wind units | \`30007 KT\`, \`18012KTS\`, \`34005MPS\` | Correct mean wind converted to integer knots |
| Visibility fraction | \`1 1/2SM\` | 2,414 m after rounding to nearest metre |
| Runway range | \`9999NDV R27L/0800\` | Surface visibility is 9999 m; runway range is not substituted |
| Cloud suffix | \`BKN015CB OVC020TCU\` | Ceiling is 1,500 ft |
| Vertical visibility | \`VV002\` | Ceiling is 200 ft |
| Precise temperature | \`M05/M10 RMK T10501106\` | Temperature is \`-5.0\` °C |
| Typed altimeter | \`QNH1013\`, \`1013HPA\`, \`A30.01\` | Correct hPa value as a one-decimal string |
| Trend isolation | Observation has \`BKN020\`, TEMPO has \`OVC005\` | Observed ceiling remains 2,000 ft |
| Relay envelope | Nested \`msg\` report with \`ts\` epoch timestamp | Report and received time are normalized correctly |

### Output invariants

- Exactly one output row per \`(station, observed_at)\`.
- A correction or replay cannot create a second output row for the same key.
- A continuation line cannot create a standalone row.
- Every output has the seven required fields, with nulls for unavailable measurements.
- Wind is an integer knot value; visibility and ceiling are integer metres/feet; temperature and altimeter follow their required string formats.
- No forecast-only value is used as the observed condition.
- All timestamps are UTC and correctly cross month/year boundaries.

## 10. Evidence and confidence

**Measured facts from the README:** score, rank, records recovered, duplicate and unmatched row counts, column-level correct/wrong/missed counts, and the 28 named data conditions with their observed recovery rates.

**Direct code findings:** early emission from \`process()\`; empty \`finalize()\`; no pending continuation buffer; station fallback can select a bulletin token; time regexes require Z and reject hour 24; the reference also rejects hour 24; the submission has broader JSON key/envelope handling than the reference.

**Inferences:** bulletin-prefix misidentification likely explains some unmatched rows. The exact share of unmatched rows attributable to that condition is not measured in the available files. The per-field wrong/missed counts identify where to investigate but do not prove a single root cause for every incorrect cell.

**Not tested:** no local synthetic benchmark or hidden-data rerun is claimed in this review. All proposed changes require targeted sample tests and a final runner validation.

## 11. Engineering takeaway

This challenge is not only a regex exercise. It tests whether the handler models the stream correctly:

1. Normalize the transport envelope.
2. Reconstruct a complete report across line boundaries.
3. Parse the observation, not the bulletin or forecast.
4. Reconstruct the event timestamp in UTC.
5. Store the latest version by its natural key.
6. Emit once, after the stream is complete.

The strongest next improvement is therefore architectural: make the output contract correct before spending time expanding every rare METAR pattern.
