---
week: 4
folder: week-04-the-interface
title: The Interface
format: python
domain: Healthcare / Clinical laboratory - HL7 v2 results
difficulty: 5
yoe_problem: 6-8
yoe_you: 4-6
yoe_gold: 5-8
confidence_you: medium
score: 0.0000
rank: 6/6
analysis: yes
---

# Week 4: The Interface - Problem overview

Python handler · score 0.0000, rank #6 of 6, run crashed at record 1,000,000 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A hospital receives every lab result as an HL7 message, a pipe-delimited text format older than the web, filed under the specimen's accession number. An interface engine logs each message as 1 JSON line, and the quality team needs **1 clean row per result** (`accession`, `test`, `patient_id`, `value`, `unit`, `observed_at`, `status`) from a log of 1,000,000 lines that should yield about 750,000 rows. The text is wrapped, escaped and sometimes malformed, a message can contain several observations, results get revised or withdrawn by later lines, and the code must fit in memory.

## 2. Domain and real-world context

**Healthcare / clinical laboratory (HL7 v2 interfaces).** Hospitals and reference labs exchange orders, results and patient events as HL7 v2 messages: segments such as `MSH`, `PID`, `OBR`, `OBX` separated by `|` and `^`. Quality teams track turnaround, abnormal values and corrected results from this data. A result attached to the wrong patient (chart numbers merged, two issuers), the wrong unit (mg/dL vs umol/L) or the wrong time (a draw time read as a run time) is a patient-safety and reporting problem, not just a data defect.

## 3. Difficulty: 5/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 33 `[measured]` |
| Output columns | 7 `[measured]` |
| Lines in the log / expected rows | 1,000,000 / 749,978 `[measured]` |
| Interface | `process` per line, `finalize` at the end `[measured]` |
| Hard limit | the run was stopped on memory, 512 MB `[measured, platform feedback; see Claude_Analysis.md]` |
| Hidden requirements | the result is *one* OBX among several; later lines revise or withdraw earlier ones; state must stay small `[inferred]` |
| Domain knowledge | HL7 v2 segments, LOINC, ADT merge events, time zones `[inferred]` |

Why 5: more than 25 interacting conditions, a real resource limit, and domain-specific formats that punish naive designs. It would be hard to make it harder without adding new message types.

## 4. Problems the data throws at you

1. **The message is nested inside a log.** Batch headers around it (25%), MLLP framing characters (3%), segments split by LF or CRLF (6%), a typed Enter inside a field (7%), doubled backslashes (3%), extra segments (20%), and key order (30%). Hard because you first have to find the message, then split it, before you can read any field.
2. **Which OBX is the result?** A panel carries several OBX (12%), plus interpretive comments under the result's own code. Hard because the result is the OBX whose code matches the test, not the first one.
3. **Who is the patient?** PID-3 lists identifiers with types and issuers, so the MRN arrives in 6 forms (12%) and two issuers both type MR (11%); merge messages move a result to a kept chart number (7%); OBR-3 may carry a namespace (4%).
4. **Which test is it?** Test codes 5 ways (15%), tests named but not coded (12%), LOINC as the alternate code (9%), an order-level code instead of the observation code (7%).
5. **Values, flags and units.** Values that are not numbers (18%), flags written in the value (20%), decimals as written (5%), units typed freely (16%), SI units beside US units as two OBX (14%).
6. **When was it drawn?** Times with no offset (12%, where the sender's time zone matters), times in 5 widths (10%), the time in SPM-17 (12%) or only on the OBX (8%), and a run time beside the draw time (25%).
7. **Lifecycle of a result.** A verified result replaces a preliminary one (8%) even if a preliminary is re-sent later, a result can be withdrawn (4%), duplicates (3%), flags outside the list (3%), truncated lines (0.5%).

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| HL7 v2 structure | Segments, fields, components, repetitions and escape sequences | `HL7 v2 segments`, `MSH PID OBR OBX`, `HL7 escape sequences` |
| Nested payload extraction | Find the real message inside a JSON log line and unescape layers | `unwrap nested json`, `MLLP framing`, `log parsing` |
| Master patient identity | Choose the right identifier and follow merges | `MRN`, `master patient index`, `ADT A40 merge` |
| Code mapping | Map local codes and names to a canonical test | `LOINC`, `terminology mapping`, `code system` |
| Unit normalization | Canonical units, case and power notation, SI vs US | `UCUM`, `unit conversion`, `mg/dL vs umol/L` |
| Time zones and DST | An offset-less time depends on the sender | `HL7 timestamp`, `DST`, `zoneinfo` |
| Versioned state (prelim to final) | The latest status wins, regardless of arrival order | `upsert`, `slowly changing`, `result lifecycle` |
| Bounded-memory streaming | Keep only what you still need before `finalize` | `memory profiling`, `streaming state`, `compact state` |
| Defensive parsing | Never let one message stop the run | `try/except scope`, `data quality` |

A short example of how HL7 fields are addressed (segment `OBX`, field 5 is the value, `^` splits components):
```
OBX|1|NM|2160-0^Creatinine^LN||1.2|mg/dL|0.6-1.3|N|||F
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **6-8 years** | medium | HL7 and clinical domain knowledge, 33 interacting conditions, versioned results, a memory budget |
| Your code (`handler.py`) | **4-6 years** | medium | 468 lines; layered unescaping and segment splitting (L32-L63), time-zone mapping with a `ZoneInfo` path and a manual DST fallback (L161-L233), unit and value parsers (L235-L292), identifier selection (L293-L318), resolve step for revisions (L422-L443); the state kept per line (`self.groups`, `self.seen`, L320-L326) is not bounded `[inferred]` |
| Gold code (`gold_submit.py`) | **5-8 years** | low | only helpers are in the file (L1-L287: message, ids, patient, time, value, unit, test); no `Handler` class `[not available]`, so the state design cannot be rated |

- Your domain handling is deep for a first HL7 task; the gap is *resource design*: deciding what to keep per line so the stream fits in memory.
- Caveat: these numbers describe the level of the problem and the code, not a person. The gold file is incomplete in this folder, so its range is low confidence.

## 7. Common traps

- **Trusting a sample to measure memory.** Sign: a 300-line sample shows only the interpreter's own footprint.
- **Splitting segments on one character.** Sign: `\r\n` leaves stray `\r` at the end of every field.
- **Taking the first OBX.** Sign: comments or the wrong analyte become the result.
- **Using the first identifier in PID-3.** Sign: SSNs or the other lab's MR number as the patient id.
- **Reading an offset-less time as UTC.** Sign: draw times hours off, and wrong across a DST change.
- **Choosing the last-arrived status.** Sign: a replay of a preliminary result overwrites the final.
- **Building every output row only at the end.** Sign: memory peaks at `finalize`, and a stop before it loses everything.
- **Keeping a fingerprint of every line forever.** Sign: dedup state grows linearly with the stream.

## 8. Mindset difference (you vs gold)

Your handler reads the domain well and tries to be complete: it keeps every candidate and decides at the end. The gold file, as far as the helpers show, favours small values that can be decided early. The lesson of this week is that correctness and footprint are one design problem. Bugs, before/after code and how to verify are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** How do you parse HL7 v2 safely? *Hint: split on the actual separators from MSH, handle escapes and repetitions, treat missing fields as empty.*
2. **(senior)** Your job processes 1M events and dies at 512 MB. How do you find out what grows? *Hint: measure on the full stream shape, not a sample; track per-key state size.*
3. **(senior)** A final result and a later re-sent preliminary arrive. How do you keep the final? *Hint: a status rank per key, compare rank before event order.*
4. **(mid)** A patient has chart numbers in two systems. How do you choose the right one? *Hint: filter by identifier type and issuer, then apply merges.*
5. **(mid)** A timestamp has no offset. What do you do? *Hint: resolve with the sender's zone, and decide what to do when the zone is unknown.*
6. **(senior)** When is it correct to drop a message instead of guessing? *Hint: when identity or time cannot be determined without inventing data.*

## 10. Learning path

**Order of study:** (1) HL7 structure and escapes → (2) one-result-per-message selection (which OBX) → (3) time zones → (4) state size and memory measurement.

**Exercise 1 - Read an OBX (30-45 min).** Parse 3 hand-written OBX lines (numeric, string, with comparator `>5`). *Self-check:* value, unit and flag come out right, and a malformed line returns `None` instead of raising.

**Exercise 2 - Local time to UTC (45 min).** Convert `20261101013000` for a Chicago sender and a New York sender. *Self-check:* the results differ by an hour and match `zoneinfo`.

**Exercise 3 - Measure state (60 min).** Generate 1M tiny lines, run a handler that stores one small tuple per key, and watch peak memory with `tracemalloc` or `resource`. *Self-check:* you can say how many bytes per key you keep and what it projects to at 750,000 keys.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 4](https://datadriven.io/community/week-4)
