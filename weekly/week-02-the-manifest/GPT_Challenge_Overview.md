# Week 2: The Manifest — Challenge Overview

## 1. Challenge at a Glance
Build a clean inventory of video renditions from a historical feed whose packagers disagree on schema, units, naming, and event conventions.
- **Input:** JSON rendition records, job events, and replays.
- **Output grain:** one row per canonical title/rendition identity, reflecting the appropriate package run.
- **Fields:** `title_id`, `rendition`, `codec`, `bitrate_kbps`, `duration_s`, `packaged_at`.
- **Core techniques:** canonicalization, unit conversion, event classification, identity resolution, and replay-safe winner selection.

## 2. Domain Knowledge
A title may have multiple **renditions**, or encoded versions at different quality levels. A rendition profile can be written as dimensions, a height, a nickname, or an object. Codec labels vary between packagers. Bitrate is normalized to kilobits per second; duration is normalized to seconds. A package run is a specific processing attempt. A job-close event describes a job and is not itself a rendition row.

## 3. Business Rules and Output Contract
Resolve nested historical schemas and key-name variants. Normalize title and rendition identity. Interpret profiles using the challenge's specific rule; convert bitrate and duration from supported units. Map codec aliases only when they correspond to allowed codecs. Treat sentinels as missing only where semantics justify it. Exclude job-close and export-bookkeeping records. Normalize timestamps and deduplicate by canonical rendition identity. An older package replay must not replace a newer run just because it arrived later.

## 4. Difficulty Assessment
**Intermediate data engineering.** The challenge combines domain-aware conversions with correct row grain and winner selection. A number without its unit is ambiguous, and arrival order does not necessarily indicate package recency.

## 5. Estimated Experience Equivalence

These estimates compare challenge demands with the patterns visible in the submitted and reference implementations. They are heuristic learning references, not validated hiring benchmarks or a judgment of the author's overall seniority.

### 5.1. Overall Comparison

| Evidence Source | Lens | Level | Estimated YoE | Short Rationale |
|---|---|---|---|---|
| Problem statement (README.md) | Challenge difficulty | Mid-level | Approximately 2–4 years of relevant data-engineering experience | Requires video-domain normalization, rendition identity, bitrate/duration unit conversion, job-close event interpretation, and choosing the newest package when old runs are replayed. |
| Your submission (handler.py) | Demonstrated implementation | Mid-level patterns | Approximately 2–3 years equivalent for the patterns demonstrated | Contains rendition/codec maps, logger-payload extraction, key aliases, and normalization helpers. Coverage still needs checking for event ordering, old-run replay, and unusual unit/profile forms. |
| Reference solution (gold_submit.py) | Solution sophistication | Senior-level problem-solving patterns | Approximately 4–5 years of relevant experience | Uses extensive alias/unit definitions, tolerant parsing, explicit numeric handling, and more elaborate state and winner-selection logic. |

These ranges are contextual estimates, not a required tenure threshold or a rating of the author's overall career level.

### 5.2. Skill-by-Skill Comparison

| Skill Group | Problem Target | Submission Evidence | Reference Evidence |
|---|---|---|---|
| JSON/log-envelope parsing | Mid | Direct and embedded payload extraction, including common logger fields | More extensive tolerant parsing and a dedicated loose-JSON path |
| Canonical fields and key mapping | Mid | Alias definitions and key-name normalization | Broader alias coverage and missing/conflict handling |
| Rendition/profile interpretation | Mid | Valid rendition and width-to-rendition maps | Explicit height/width mappings and additional profile cases |
| Codec normalization | Junior–Mid | Canonical codec names and aliases | Broader vocabulary handling and contract-aware mapping |
| Bitrate and duration conversion | Mid | Normalization helpers; edge-case coverage needs testing | More detailed unit parsing and numeric handling |
| Event semantics and row identity | Mid–Senior | Close-event and package-recency behavior needs verification | More explicit incomplete-context and latest-package selection |
| Replay safety and final emission | Mid–Senior | Must be validated against duplicates and old-run re-delivery | More developed state and candidate-selection approach |

### 5.3. Evidence Behind the Estimate

- The README describes renditions represented as nicknames, numbers, dimensions, or nested objects; bitrate and duration in different units; and job-close events that are not rendition rows.
- An old package replay must not replace a newer package merely because it arrived later. This separates arrival order from business recency.
- The submission has explicit rendition/codec mappings, key normalization, and payload extraction—stronger than simple field projection.
- The reference includes broader normalization and recovery logic. Its mappings and winner rules still need to match the contract.

### 5.4. What Each Level Looks Like Here

| Level | Expected Demonstration |
|---|---|
| Beginner / Entry-level | Reads JSON and extracts fields when names and formats are stable. |
| Junior Data Engineer | Normalizes common aliases and converts well-defined units. |
| Mid-level Data Engineer | Handles schema variants, unit drift, domain vocabulary, event classification, deterministic identity, and duplicate delivery. |
| Senior-level problem-solving | Designs replay-safe state that handles delayed context and old backfills without allowing arrival order to override package recency. |

### 5.5. Assumptions and Limitations

1. README.md defines the contract; handler.py shows the submission patterns; gold_submit.py is one reference approach.
2. The assessment is based on visible code structure, not a claim that every edge case passes or fails.
3. Reference sophistication does not guarantee correctness; mappings and winner semantics must be tested.
4. YoE ranges are illustrative, not an empirical conversion from code complexity to years.
5. This section concerns the challenge and code patterns, not the author's overall professional seniority.

**Overall conclusion:** Week 2 is a Mid-level data-engineering challenge. The submission demonstrates meaningful normalization patterns; the key advanced concepts to validate are job-close context, unit edge cases, deterministic winner selection, and replay safety.

## 6. Core Engineering Patterns
- Canonical dimensions and stable business keys.
- Unit-aware parsing that keeps values and units together.
- Event classification between rendition facts and job metadata.
- Deterministic winner selection using package-run metadata.
- Replay-safe processing and layered validation.

## 7. Common Traps
- Interpreting a profile using the wrong dimension.
- Treating every duration as seconds or bitrate as kbps.
- Treating a job-close line as a rendition.
- Mapping unsupported codecs to supported ones.
- Using the last line seen as the newest package.
- Deduplicating raw text instead of canonical business identity.

## 8. Independent Examples
**Bitrate:** `"5 Mbps"` becomes `5000 kbps` after parsing its unit.

**Duration:** `125000 ms` becomes `125 seconds` when the source's unit is documented as milliseconds.

**Replay:** if a 10:00 package is replayed after the 12:00 package, package metadata—not arrival order—should determine the winner.

## 9. Technical Topics to Study
1. JSON normalization and schema evolution.
2. Numeric parsing with units and basic video codec/profile concepts.
3. Timestamp and duration formats.
4. Business keys, deterministic deduplication, and latest-state selection.

## 10. Suggested Learning Plan
1. Build independent parsers for title ID, rendition, codec, bitrate, duration, and timestamp.
2. Test each parser against multiple valid forms and invalid sentinels.
3. Define a canonical rendition key.
4. Separate rendition events from job metadata.
5. Define package recency explicitly.
6. Test duplicates, retries, and old backfills.

## 11. Validation Checklist
- [ ] Are nested schemas and key naming styles resolved?
- [ ] Are bitrate and duration converted from documented units?
- [ ] Are profiles interpreted using the challenge's exact rule?
- [ ] Are codec aliases mapped explicitly?
- [ ] Are job events excluded from rendition output?
- [ ] Can an older replay arrive after a newer package without winning?
- [ ] Is output exactly one row per rendition key?

## 12. Evidence and Assumptions
The README documents the streaming scenario, output fields, unit drift, job-close events, and older-run replays. `handler.py` and `gold_submit.py` were reviewed for interface and technical context. Estimates are heuristic; exact profile interpretation, codec mappings, and winner rules must follow the challenge contract.
