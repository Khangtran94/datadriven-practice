# Week 1 – The Handoff: Challenge Overview

## 1. One-sentence verdict
This is a medium dirty-JSON streaming challenge for a data engineer with roughly 1–2 years of experience cleaning CRM / customer exports.

## 2. Domain & context
- **Simulated business**: a company retiring a CRM used since 2019 through multiple rewrites and ownership changes.
- **Pipeline goal**: produce one clean row per customer for the finance team to close the fiscal year.
- **Raw inputs**: a nightly JSON export stream, one object per customer, written by whoever last touched the exporter. Keys, nesting, null spellings, date formats and plan names vary by era and region.

## 3. Core data-engineering problems
The README injects the following intentional difficulties (ordered roughly by frequency/impact):

1. **Key order changes** – JSON objects are unordered; parsers must not rely on position.
2. **Broken JSON structure** – string concatenation instead of proper serialisation breaks strict parsers.
3. **Nesting and flattening** – fields moved in and out of sub-objects across rewrites; the same value sits at different depths.
4. **Localized key names** – regional instances used different field labels that were never translated back.
5. **Epoch seconds or millis + mixed date formats** – timestamps appear as epoch numbers, ISO strings, or locale-specific forms, sometimes without zone.
6. **Nulls spelled as strings, padding/casing, numbers as strings** – absence written in many ways; values carry spreadsheet padding; money and counts formatted for humans.
7. **Plan aliases and emails with display names** – free-text eras left multiple spellings; addresses arrive with display names and mailto: prefixes.
8. **Duplicate records** – at-least-once delivery requires identity settlement (last write or first, per contract).
9. **Truncated lines and plans outside the contract** – partial writes and retired plans that must stage as null.

Scoring penalises both missed rows and extra rows for the same customer key.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Tolerant JSON parsing | Broken structure, truncated lines and nested objects require recovery rather than fail-fast. |
| Key normalisation & multi-path lookup | Localized names, nesting changes and case variation mean the same logical field lives under many keys. |
| Timestamp normalisation | Epoch (s/ms), ISO, mixed formats and missing zones must become a single UTC ISO string. |
| Null / sentinel cleanup | Many string spellings of absence must become true NULL before type coercion. |
| Identity & deduplication | Duplicate records and re-deliveries require keeping only one row per customer_id. |
| Type coercion & validation | Numbers as strings, plan aliases, email extraction, and contract-constrained values (seats, mrr, plan). |
| Streaming state | Handler must accumulate the latest good row and emit only in finalize. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Medium | 1–2 years | Classic dirty-JSON cleaning with many real-world patterns, but single entity and straightforward identity. |
| Your submission (`handler.py`) | Junior | ~1 year | Basic class + dict for last-write, limited key/date/null handling, emitted intermediate rows, missed most nesting/localization/broken-JSON cases. |
| Reference solution (`gold_submit.py`) | Mid | 2–3 years | Comprehensive tolerant parser, multi-path key lookup, full date/epoch coverage, proper finalize-only emission and contract validation. |

## 6. Skill map

**Primary skills trained**
- Tolerant parsing of messy JSON streams
- Multi-source field normalisation and null cleanup
- Identity-based deduplication in a streaming handler

**Secondary skills**
- Date/epoch normalisation to UTC
- Email and plan-alias extraction
- Contract-constrained type coercion

**Can be deferred on a first pass**
- Perfect recovery of every truncated or heavily broken line
- Micro-optimisations of the lookup order

## 7. Learning path
1. Expand key lookup to cover nested paths, localized names and case variation before any type coercion.
2. Add a robust timestamp parser that handles epoch seconds/millis, ISO with/without zone, and common locale formats, always emitting UTC ISO.
3. Move all emission to `finalize`, keep only the latest valid row per customer_id, and add null-string and plan-alias maps. Then re-score against the column percentages in the README.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong, the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
