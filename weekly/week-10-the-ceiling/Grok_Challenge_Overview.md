# Week 10 – The Ceiling: Challenge Overview

**One-sentence verdict:** A demanding production-grade streaming METAR parser (2–3+ YoE) that turns noisy airport weather reports into a clean observation table for airline delay analysis.

## Domain & context

You are a data engineer at an airline. Every airport on earth reports its weather roughly once an hour as a METAR — a compact, teletype-era code that pilots still read. Collectors logged each report as a JSON line (sometimes wrapped, sometimes continued across two lines, sometimes carrying bulletin headers or local-time envelopes). The dispatch team needs one clean row per observation (station + observed_at + wind, visibility, ceiling, temperature, altimeter) to study delays around New Year.

The raw stream is deliberately hostile: hand-typed units, missing Zulu designators, hour-2400 midnights, split lines, O-for-0 typos, TEMPO/BECMG forecasts that must be ignored, CAVOK, CB/TCU layers, late backlog after outages, and many collector-specific wrappers.

## Core data-engineering problems

1. **Streaming contract** — process one line at a time, emit only in `finalize`, last-write-wins on (station, observed_at).
2. **Line continuation / pending body** — a report can be split across two log lines; the second has no station or time of its own.
3. **Robust METAR tokenization** — extract station, time, wind, visibility, ceiling, temperature and altimeter from a free-form string that tolerates dozens of real-world variants.
4. **Time recovery** — day-of-month only, optional Z, hour 2400, local-time envelopes, month/year rollover near midnight, late backlog after outages.
5. **Unit normalization** — knots, m/s, km/h, statute miles (including fractions), metres, inches of mercury, hectopascals, QNH, hand-typed forms.
6. **Forecast / remark cut-off** — ignore TEMPO, BECMG, RMK and everything after them.
7. **Collector noise** — bulletin headings, archive date lines, relay formats, bookkeeping fields, lower-case, trailing `=`, line wraps.
8. **Special weather codes** — CAVOK, VV (vertical visibility as ceiling), NDV, runway visual range, missing sensors, NIL.

## Concepts you must master

| Concept | Why it appears |
|---------|----------------|
| Streaming state machine | Split lines and last-write-wins require memory across `process` calls |
| Regular expressions (heavy) | Almost every field is extracted by a carefully tuned pattern |
| Datetime arithmetic | Day-of-month + received stamp → full UTC timestamp, including rollovers and 2400 |
| Last-write-wins / keying | Multiple copies and corrections of the same observation |
| Tokenization & re-joining | Hand-typed two-part groups ("10 SM", "A 3001", "180/12KT") |
| Defensive parsing | O-for-0, missing zeros, mixed case, extra spaces, trailing equals |
| Domain knowledge | METAR structure, CAVOK, CB/TCU, TEMPO/BECMG, altimeter units |

## Difficulty & experience estimate

| Artifact | Level | Estimated YoE | Rationale |
|----------|-------|---------------|-----------|
| Problem statement (README) | Hard | 2–3 years | Many intentional edge cases; requires both streaming architecture and domain-aware parsing. |
| Your submission (`handler.py`) | Intermediate–Hard | 1–2 years | Solid JSON normalization and field extractors, but emits on every change (duplicates) and misses several high-frequency METAR variants. |
| Reference solution (`gold_submit.py`) | Production-grade | 3–5 years | Compact state machine, pending-line buffer, large battle-tested regex set, correct last-write-wins, and careful date arithmetic. |

## Skill map

- **Primary:** streaming handlers, regex-driven parsing, datetime recovery, last-write-wins deduplication
- **Secondary:** unit conversion, defensive string cleaning, domain-specific aviation codes
- **Can defer:** perfect handling of every rare bulletin format once the core contract and the top-frequency conditions are solid

## Learning path

1. Change the Handler so `process` always returns `[]` and `finalize` emits the unique last-write-wins table (eliminates the 60 k duplicate-row penalty).
2. Add a pending-body buffer for split lines and compare your recovery on the "Split over 2 log lines" condition.
3. Study the gold regex set (`_HEAD`, `_WIND`, `_ALTIMETER_TYPED`, etc.) and incrementally port the highest-impact patterns (no-Z time, 2400, KTS/QNH, two-part values).

## How this pairs with Grok_Analysis.md

This overview explains the aviation domain, the intentional hardness of the stream, and the skills required. The companion `Grok_Analysis.md` shows the concrete code differences between your `handler.py` and the gold solution, ordered by score impact, with before/after snippets you can copy.
