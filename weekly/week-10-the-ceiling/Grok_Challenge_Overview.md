# Week 10 – The Ceiling: Challenge Overview

## 1. One-sentence verdict
This is a hard aviation-weather parsing challenge for a data engineer with roughly 3–5 years of experience in streaming text / sensor-log pipelines — with a strong requirement for last-write-wins state and tolerant METAR decoding.

## 2. Domain & context
- **Simulated business**: an airline studying delay patterns around New Year.
- **Pipeline goal**: one clean row per METAR observation (station + observed_at) containing wind, visibility, ceiling, temperature and altimeter.
- **Raw inputs**: collector logs of METARs, each logged as one JSON line. METAR is a terse teletype code designed for pilots; collectors add their own envelope, wrap lines, replay after outages, and occasionally lower-case or re-format the report.

## 3. Core data-engineering problems
The README deliberately injects the following production realities (ordered by cost):

1. **Value typed in two parts** – 30007 KT, 10 SM, BKN 015, 22 / 14, A 3001.
2. **Hand-typed units** – KTS, KM, QNH1013, 1013HPA, A30.01, CALM.
3. **Key order changes** – JSON objects are unordered; never rely on field order.
4. **Time without Z / hour 2400** – 311851, 311851UTC, 312400Z.
5. **Bulletin heading or archive date line in front** – SAUS70 KWBC 311900 or a date stamp above the report.
6. **Negative temperatures** – M05, T10501106 (tenths in remarks), free-form -05 / 22.4.
7. **CAVOK** – single word replaces visibility and cloud groups.
8. **Trailing = and split over two log lines** – circuit wrap at 69 characters; continuation must be joined.
9. **Wind in m/s** – MPS groups; convert to knots.
10. **Collector bookkeeping, NDV, runway visual range, TEMPO/BECMG outlooks**.
11. **Late replay after outage** – day-of-month must be resolved against the receipt stamp (or New-Year anchor).
12. **Letter O typed for zero, lower-case lines, exact duplicates, sensor-out / NIL**.

On top of correctness the identity of a report is (station, observed_at); later copies supersede earlier ones and must not produce a second emitted row.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| METAR / SPECI grammar | Station, time group, wind, visibility, cloud layers, temp/dew, altimeter; optional remarks and trends. |
| Last-write-wins streaming state | Same (station, observed_at) can arrive multiple times; keep only the latest (or best) version. |
| Tolerant tokenisation | Hand-typed units, split groups, letter-O, free-form decimals, mixed SM fractions. |
| Day-of-month anchoring | Report carries only DD; year/month come from the collector stamp or a known New-Year window. |
| Continuation / pending state | Circuit-wrapped reports arrive as two consecutive lines that must be rejoined. |
| Unit conversion & rounding | MPS/KMH → knots, SM → metres, inches Hg → hPa; integer / one-decimal conventions. |
| Trend-group isolation | TEMPO / BECMG / NOSIG must not be read as the observation itself. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3–5 years | Real METAR surface + collector artefacts + strict identity semantics. |
| Your submission (`handler.py`) | Mid–Senior | ~3 years | Score 0.8185 (4th). Strong extraction on clean reports; losses concentrated on second-row emissions, split lines, no-Z times and typed units. |
| Reference solution (`gold_submit.py`) | Senior+ | 5+ years | Compact held state, pending-line recovery, broad header/time/unit patterns, and emission only from finalize. |

## 6. Skill map

**Primary skills trained**
- Streaming last-write-wins design (single winner per key, emit only at finalize)
- Robust METAR body parsing (wind / visibility / ceiling / temp / altimeter)
- Day-of-month and time-form recovery against a receipt anchor

**Secondary skills**
- Continuation-line detection and join
- Legacy / typed-unit field recovery
- Filtering of trend groups and collector bookkeeping

**Can be deferred on a first pass**
- Exhaustive recovery of every rare remark or outside-list visibility qualifier once the main identity and unit paths are solid

## 7. Learning path
1. Change architecture: store one weather tuple per (station, observed_at); never emit from process; emit the whole map from finalize.
2. Add pending-state recovery for reports split across two log lines.
3. Widen time patterns (optional Z, hour 2400) and unit/token patterns (KTS, QNH, two-part values, mixed SM); re-measure the high-cost columns.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the airline/METAR problem, the intentional collector and coding difficulties, and the experience bar.
- **Grok_Analysis.md** = understand exactly why second-row emissions and missing records cost points, the concrete before/after state design, and the highest-impact extractor fixes.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
