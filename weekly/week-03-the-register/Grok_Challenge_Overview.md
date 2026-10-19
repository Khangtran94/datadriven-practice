# Week 3 – The Register: Challenge Overview

## 1. One-sentence verdict
This is a hard interval-data challenge for a data engineer with roughly 2–4 years of experience in utilities / IoT / time-series billing pipelines.

## 2. Domain & context
- **Simulated business**: an electric utility cutting over to a new billing system.
- **Pipeline goal**: produce one clean row per meter per half-hour so every smart-meter reading moves into the new system.
- **Raw inputs**: a JSON line feed of meter reports (usage and/or register). The meter feed is the only copy of the history that must be migrated.

## 3. Core data-engineering problems
The README deliberately injects the following production realities:

1. **Local time with DST (CDT/CST)** – fall-back creates two 01:30 half-hours that only the zone label distinguishes.
2. **Interval stamped at start vs end** – one head-end names the half-hour by its beginning; read as an end, every such row lands on the previous slot.
3. **Fill-in then real read** – estimates are replaced by real reads; a later replay of the estimate must not win.
4. **Running totals only (register → usage)** – older meters report only the cumulative register; usage is the difference in interval order, not arrival order.
5. **Wh vs kWh and unit-in-value** – the same energy arrives with different scales and unit spellings.
6. **CDC envelopes** – some lines are change-data-capture wrappers (before/after images).
7. **Quality / read flags per maker**, null-as-text, padding on meter ids, late bursts, truncated and double-serialized JSON.

Correct interval alignment and “real read beats estimate” ranking are central to the score.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Half-hour interval alignment | Start-stamped vs end-stamped conventions; DST fall-back ambiguity. |
| Derived measures from running totals | Usage = Δ register in chronological interval order. |
| Quality ranking (real > estimate) | Fill-in lines must never overwrite a later or earlier real read. |
| Unit normalisation (Wh/kWh) | Scale and unit text determine the numeric meaning. |
| CDC / envelope unwrapping | Some lines carry the row inside an operation wrapper. |
| Streaming handler + ordered state | Late bursts arrive out of wall-clock order but in interval order. |
| Meter-id normalisation | Padding, missing dashes, and casing variants. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 2–4 years | Time-zone/DST, start-vs-end stamping, and register→usage derivation are classic utility pitfalls beyond ordinary JSON cleaning. |
| Your submission (`handler.py`) | Mid | ~2–3 years | Solid overall recovery (score 0.7693); main gaps are DST/local-time handling, start-stamped intervals, and some estimate-vs-real ranking. |
| Reference solution (`gold_submit.py`) | Senior | 4–5 years | Full interval algebra, quality ranking, unit and flag tables, and robust recovery of CDC/dirty JSON under late delivery. |

## 6. Skill map

**Primary skills trained**
- Interval and time-zone correctness (including DST)
- Deriving usage from cumulative registers in order
- Quality / provenance ranking of competing reads

**Secondary skills**
- Unit and flag normalisation across head-ends
- CDC envelope handling and tolerant JSON

**Can be deferred on a first pass**
- Exhaustive recovery of every truncated or outside-contract flag

## 7. Learning path
1. Implement a single, explicit rule for interval_end (and DST fall-back) and verify against the “stamped at the start” and “local time” conditions.
2. Add register→usage derivation that processes intervals in time order, not arrival order.
3. Encode quality ranking so a real read always beats a later estimate, then harden unit and meter-id normalisers.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the utility metering problem, the intentional time-series difficulties, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong, the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
