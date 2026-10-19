# Week 4 – The Interface: Challenge Overview

## 1. One-sentence verdict
This is a hard HL7 / healthcare-interface challenge for a data engineer with roughly 3 years of experience parsing legacy clinical messaging formats.

## 2. Domain & context
- **Simulated business**: a hospital quality team that needs clean lab results.
- **Pipeline goal**: produce one clean row per result (accession + test) from an interface-engine log of HL7 messages.
- **Raw inputs**: JSON lines each containing an HL7 message (or a batch, or a double-escaped frame). Messages use | and ^ delimiters, variable-width timestamps, multiple OBX segments, MRN merges, and many local coding conventions.

## 3. Core data-engineering problems
The README injects a large set of intentional difficulties (the week that produced a score of 0):

1. **HL7 structure** – segments, fields, components, repetitions; MLLP framing; batch headers; lines split by LF or CRLF.
2. **More than one OBX** – panels and comments; the result is the numeric OBX whose code maps to a contract test.
3. **Test codes, 5 ways** – LOINC, local, both, long name, or name-only; alternate identifier slots.
4. **MRN in 6 forms + merges** – PID-3 lists with type/issuer; ADT merge messages (A40 etc.) that remap retired numbers.
5. **Times with no offset / 5 widths / moved locations** – OBR-7, OBX-14, SPM-17; two labs in two time zones.
6. **Units as typed + SI beside US** – free-text, coded, micro-sign, 10*3/uL synonyms; dual reporting.
7. **Values that are not numbers** – comparators, structured numerics, flags written inside the value field.
8. **Status ranking** – preliminary → final → corrected; withdrawn by W; order-level vs observation-level status.
9. **Engine bookkeeping, double-escaping, truncated lines, flags outside the list**.

Scoring is all-or-nothing on identity; the run crashed before any rows were emitted.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| HL7 segment/field parsing | Messages are pipe-delimited text with components (^), repetitions (~) and escapes. |
| Multi-OBX selection | Choose the numeric observation that matches a contract test code or name. |
| Identifier normalisation | MRN extraction from PID-3 lists; merge-message remapping of retired numbers. |
| Timestamp recovery | Variable-width HL7 DTMs, missing offsets, two zones, collection vs run time. |
| Unit & value cleaning | Free-text units, SI/US dual reporting, comparator values, flags embedded in the value. |
| Status ranking & revision | Later final/corrected results replace preliminaries; W withdraws the value. |
| Double-escaping & framing | JSON + HL7 escapes, MLLP bytes, batch wrappers must be unwrapped before parsing. |
| Streaming identity with ranking | Keep candidates per (accession, test) and pick the highest-status non-truncated winner in finalize. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3 years | Full HL7 parsing, clinical coding conventions, merges and timezone logic; many interacting conditions. |
| Your submission (`handler.py`) | Mid | 2–2.5 years | Ambitious parser with escapes, ranking and zone logic, but stored every candidate and crashed (OOM/timeout) before finalize could emit. |
| Reference solution (`gold_submit.py`) | Senior | 3–5 years | Compact state, robust HL7 unwrapping, correct OBX/MRN/time/unit selection and status ranking that survives the full stream. |

## 6. Skill map

**Primary skills trained**
- Parsing HL7 v2 messages (segments, components, escapes, framing)
- Selecting the correct OBX and normalising test codes / units / values
- MRN extraction and merge remapping
- Status-ranked identity in a memory-efficient streaming handler

**Secondary skills**
- Timezone-aware timestamp recovery
- Double-escape and truncated-line recovery
- Contract filtering (only final/preliminary/corrected)

**Can be deferred on a first pass**
- Perfect recovery of every exotic unit synonym or truncated batch
- Full historical merge-chain walking if the simple map suffices

## 7. Learning path
1. Reduce memory: keep only the current winner per (accession, test) instead of every candidate; emit only in finalize.
2. Harden the HL7 unwrap (double escapes, MLLP, batch headers, CRLF) and the OBX selection so the contract tests are found reliably.
3. Add the status ranking and MRN merge map, then verify a small sample of accessions against the gold before re-running the full stream.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong (especially the crash), the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
