# Week 2 – The Manifest: Challenge Overview

## 1. One-sentence verdict
This is a medium-hard stream-cleaning challenge for a data engineer with roughly 2–4 years of experience in media / video packaging pipelines.

## 2. Domain & context
- **Simulated business**: a video streaming service preparing for a launch weekend.
- **Pipeline goal**: produce one clean row per rendition so the delivery team knows what is ready to cache near viewers.
- **Raw inputs**: a multi-year JSON line feed (one line per rendition) written by packaging jobs since 2020. The feed is the only record of what was actually made.

## 3. Core data-engineering problems
The README deliberately injects the following production realities:

1. **Rendition expressed many ways** – WxH, bare height, nicknames (FHD/4K), or nested width/height objects.
2. **Job-close lines** – outputs land before the job’s close line that carries the title; incomplete lines must wait.
3. **Codec tags from three toolchains** – RFC 6381 profiles, library names, marketing names → four canonical codecs.
4. **Rate and duration unit drift** – bps / kbps / Mbps, milliseconds / timecode / ISO duration / minutes; sentinels (0, −1, NaN).
5. **Nesting, key-case variants, broken/logger JSON** – fields move in and out of sub-objects; lines carry prefixes and truncation.
6. **Re-delivery of older runs** – backfills replay older packages; the newest package run must win.
7. **Duplicates, null-as-text, padding/casing** – classic stream noise on top of the media-specific issues.

Second-row penalties and empty `finalize` are expensive; architecture matters as much as field recovery.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Streaming handler contract | Hold incomplete outputs; emit only from `finalize` to avoid second-row cost. |
| Job context / late title attachment | Close lines carry title after outputs; incomplete rows must be parked. |
| Multi-form categorical normalisation | Rendition, codec, bitrate, duration each have several legitimate spellings and units. |
| Nested and case-variant keys | Rewrites and toolchains move fields and change case. |
| Tolerant JSON recovery | Logger prefixes, BOM, truncated lines, broken quoting. |
| Newest-run wins under re-delivery | Backfills must not overwrite a newer package. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Medium–Hard | 2–4 years | Media-specific unit and codec variety plus job-close ordering and re-delivery make this harder than pure CRM cleaning. |
| Your submission (`handler.py`) | Mid | ~2–3 years | Strong recovery overall (score 0.8266, rank #3); main gaps are emit architecture, job-close handling, and some nested/JSON edge cases. |
| Reference solution (`gold_submit.py`) | Senior | 4–5 years | Full defensive parse, rich alias/unit tables, job-context parking, and clean emit-once design that maximises both recovery and correctness. |

## 6. Skill map

**Primary skills trained**
- Streaming state design (hold vs emit)
- Domain normalisation (rendition / codec / bitrate / duration)
- Late-arriving context (job close lines)

**Secondary skills**
- Nested JSON flatten and key-case handling
- Sentinel rejection and unit inference by magnitude

**Can be deferred on a first pass**
- Exhaustive recovery of every truncated or outside-contract codec line

## 7. Learning path
1. Enforce emit-only-from-`finalize` and confirm zero second-row penalties.
2. Add explicit job-context parking so outputs that arrive before the close line inherit the title.
3. Expand rendition/codec/bitrate/duration normalisers (including sentinels and unit drift) and re-check the README condition table.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the packaging/manifest problem, the intentional media-data difficulties, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong, the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
