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
These are heuristic learning references, not validated industry benchmarks or a personal ability assessment.

| Skill | Approximate experience equivalent | Rationale |
|---|---|---|
| JSON and schema normalization | 1–3 years | Historical nested fields and naming variation |
| Unit conversion and domain parsing | 1–3 years | Bitrate, duration, codec, profile variants |
| Event semantics and identity | 2–4 years | Distinguishing job events from rendition rows |
| Replay-safe latest-state logic | 2–4 years | Backfills can arrive after newer runs |

**Challenge-level estimate: roughly 2–4 years of practical data engineering experience.** The README establishes scope; `handler.py` establishes the interface; `gold_submit.py` demonstrates one approach. These sources estimate task demands, not the user's overall skill. The reference is not the only valid solution.

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
