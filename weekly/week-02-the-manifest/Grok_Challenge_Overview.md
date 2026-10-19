# Week 2 – The Manifest: Challenge Overview

## 1. One-sentence verdict
This is a medium-hard video-packaging feed challenge for a data engineer with roughly 2 years of experience normalising media-rendition metadata.

## 2. Domain & context
- **Simulated business**: a video streaming service preparing for a launch weekend.
- **Pipeline goal**: produce one clean row per rendition so the delivery team can decide what to cache near viewers.
- **Raw inputs**: a multi-year JSON feed, one line per rendition (or job-close), written by several packagers since 2020. Keys, nesting, units, codecs and timestamps vary by toolchain.

## 3. Core data-engineering problems
The README injects the following intentional difficulties:

1. **Rung as size, name or number** – profiles named WxH, bare height, nicknames (FHD) or nested objects; scope titles require width-based reading.
2. **Nesting and flattening** – fields moved into/out of video/asset/timing objects across rewrites.
3. **Job close lines** – packager writes output lines then a close line that carries the title but no rendition; close lines must not become rows.
4. **Broken JSON structure** – timestamp prefixes, BOM, trailing junk, value-dependent quoting.
5. **Epoch / mixed date formats + rate unit drift** – bps, Mbps, human strings; length as ms, timecode, ISO duration or minutes.
6. **Codec tags from 3 toolchains** – RFC 6381, library names, marketing names must map to one of four contract codecs.
7. **Sentinels, nulls as strings, key-case variation, numbers as strings**.
8. **Duplicate records and re-delivery of older runs** – newest package run wins; arrival order is irrelevant.
9. **Truncated lines and codecs outside the contract**.

Scoring rewards correct identity (title_id + rendition) and penalises extra rows.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Multi-path / nested field extraction | Rung, codec, duration and bitrate live at different depths and under different names. |
| Unit normalisation | Bitrate (bps/Mbps/k) and duration (ms/timecode/ISO/minutes) must become consistent numeric units. |
| Codec vocabulary mapping | Three toolchain spellings collapse to the four contract codecs; others become null. |
| Job-close filtering | Close lines carry title but no rendition and must be ignored or used only for context. |
| Newest-run wins | Re-deliveries of older packaging runs must lose to the latest packaged_at. |
| Tolerant JSON + null cleanup | Broken lines, sentinels (0/-1/NaN) and string-nulls require recovery and cleaning. |
| Streaming identity | Accumulate the best row per (title_id, rendition) and emit only in finalize. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Medium-hard | 2 years | Many media-specific normalisations (rung, codec, units, job-close) on top of classic dirty JSON. |
| Your submission (`handler.py`) | Mid | 1.5–2 years | Solid recovery and ranking; high score (0.83) shows most conditions handled; remaining gaps in rung/codec/unit edge cases. |
| Reference solution (`gold_submit.py`) | Mid-senior | 2–3 years | Complete multi-path extraction, unit/codec maps, job-close logic and newest-run ranking. |

## 6. Skill map

**Primary skills trained**
- Nested and multi-key field extraction from media packaging feeds
- Unit and vocabulary normalisation (bitrate, duration, codec, rung)
- Newest-wins identity across re-deliveries

**Secondary skills**
- Job-close line filtering
- Tolerant JSON recovery
- Sentinel and string-null cleanup

**Can be deferred on a first pass**
- Perfect recovery of every truncated line
- Exhaustive coverage of every exotic rung nickname

## 7. Learning path
1. Build a single `extract` helper that walks nested objects and tries every known key/alias for title_id, rendition, bitrate, codec, duration and packaged_at.
2. Add explicit unit converters (bitrate → kbps, duration → seconds) and a codec map that collapses the three toolchain spellings.
3. In finalize keep only the row with the latest packaged_at per (title_id, rendition); ignore pure job-close lines. Re-score against the column percentages.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong, the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
