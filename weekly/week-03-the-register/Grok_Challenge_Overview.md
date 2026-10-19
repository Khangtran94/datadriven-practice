# Week 3 – The Register: Challenge Overview

## 1. One-sentence verdict
This is a medium-hard smart-meter interval challenge for a data engineer with roughly 2 years of experience handling time-series utility data and late arrivals.

## 2. Domain & context
- **Simulated business**: an electric utility going live with a new billing system.
- **Pipeline goal**: produce one clean row per meter per half-hour interval so billing can calculate usage.
- **Raw inputs**: a JSON feed of smart-meter reports (energy used + register total). Meters report every half hour; some only send the running register; times are local (CDT/CST); estimates are later replaced by real reads.

## 3. Core data-engineering problems
The README injects the following intentional difficulties:

1. **Local time, CDT or CST** – fall-back night has two 01:30s; only the zone label distinguishes them.
2. **Stamped at the start** – some head-ends name the interval by its beginning; reading it as an end shifts every row.
3. **Fill-in, then the real read** – estimates must be replaced by the later real read; re-sent estimates after the real read still lose.
4. **CDC envelopes** – change-data-capture lines carry before/after images; the row is the after image.
5. **Running totals, no usage** – older meters send only the register; usage is the difference from the previous interval (must be computed in interval order).
6. **Wh in place of kWh** – unit may be in the value, a sibling field, or the field name; magnitude tells which.
7. **JSON as a quoted string, broken structure, nulls as strings, padding/casing**.
8. **Read flags per maker** – different codes for actual vs estimated; SUB = substituted/estimate.
9. **Reads that come in late** – radio-loss bursts arrive out of wall-clock order but in interval order.
10. **Truncated lines and flags outside the contract**.

Scoring requires correct (meter_id, interval_end) identity and accurate usage/register/quality.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Interval identity & timezone | Half-hour buckets in local time with DST fall-back; start-vs-end stamping. |
| Register-to-usage differencing | Running totals must be differenced in true interval order, not arrival order. |
| Estimate vs actual replacement | Later real reads overwrite earlier fill-ins; quality flag must reflect the winner. |
| Unit normalisation | Wh vs kWh (and unit embedded in value or field name). |
| CDC unwrapping | Extract the after-image from change envelopes. |
| Late-arriving data | Out-of-order bursts still produce correct previous-interval differences. |
| Tolerant JSON + null cleanup | Quoted-string JSON, broken lines, string-nulls, padding. |
| Streaming state per meter | Keep enough history to compute differences and choose the winning quality. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Medium-hard | 2 years | Time-series identity, DST, register differencing and late data on top of dirty JSON. |
| Your submission (`handler.py`) | Mid | 1.5–2 years | Good recovery and scoring (0.77); remaining gaps mainly in start-stamped intervals, unit conversion and some quality flags. |
| Reference solution (`gold_submit.py`) | Mid-senior | 2–3 years | Correct interval normalisation, register differencing in order, quality ranking and unit handling. |

## 6. Skill map

**Primary skills trained**
- Half-hour interval identity under DST and start-vs-end conventions
- Computing usage from running registers in true chronological order
- Quality / estimate-vs-actual ranking

**Secondary skills**
- Unit (Wh/kWh) normalisation
- CDC envelope unwrapping
- Late-data handling in a streaming handler

**Can be deferred on a first pass**
- Perfect recovery of every truncated or double-encoded line
- Exhaustive maker-specific flag synonyms

## 7. Learning path
1. Normalise every timestamp to a canonical interval_end (handle start-stamped, CDT/CST, epoch) before any differencing.
2. Maintain per-meter ordered state so usage can be computed as register_diff when the feed supplies only the total; apply quality ranking so real reads replace estimates.
3. Add Wh→kWh conversion and emit only in finalize. Re-score against the usage_kwh and quality columns.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong, the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
