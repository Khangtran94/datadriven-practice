# Week 1 – The Handoff: Challenge Overview

## 1. One-sentence verdict
This is a medium stream-cleaning challenge for a data engineer with roughly 1–3 years of experience in CRM / SaaS migration pipelines.

## 2. Domain & context
- **Simulated business**: a company retiring a long-lived CRM (in use since 2019, through 3 rewrites and a change of owner).
- **Pipeline goal**: produce one clean row per customer so Finance can close the fiscal year.
- **Raw inputs**: a nightly export stream of one JSON object per customer, written by whoever last touched the exporter. The CRM team has left; this final stream is the only feed left.

## 3. Core data-engineering problems
The README deliberately injects the following production realities:

1. **Key-order independence** – JSON objects are unordered; positional parsing fails.
2. **Broken / concatenated JSON** – the exporter builds strings by hand; strict parsers drop lines.
3. **Nesting and flattening across rewrites** – the same field sits at different depths depending on write date.
4. **Localized / aliased key names** – regional instances and free-text eras never normalized keys.
5. **Epoch seconds vs millis and mixed date formats** – signup times arrive in several numeric and string conventions.
6. **Nulls spelled as strings, padding, casing** – absence is written many ways; values keep spreadsheet noise.
7. **Plan aliases, numbers-as-strings, emails with display names** – free-text plans, formatted money/seats, and `Name <email>` forms.
8. **Duplicates and truncated lines** – at-least-once delivery and mid-line cuts.

The harness penalises a second emitted row for the same customer key heavily.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Streaming handler contract (`process` / `finalize`) | Rows must be held and emitted once; early emit causes second-row penalties. |
| Tolerant JSON recovery | Broken structure, truncated lines, and logger-style concatenation are common. |
| Key aliasing + recursive flatten | Localized names and nested objects from successive CRM rewrites. |
| Timestamp normalisation | Epoch s/ms, mixed string formats, ambiguous US dates. |
| Identity + dedup | Same customer appears more than once; only one final row is allowed. |
| Domain value cleaning | Plan aliases, seats/MRR as formatted strings, emails with display names. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Medium | 1–3 years | Classic dirty JSON stream with nesting, aliases, and timestamp variety; architecture (emit-once) is the main trap. |
| Your submission (`handler.py`) | Junior–Mid | ~1–2 years | Recovers a solid share of clean rows but emits from both `process` and `finalize`, causing a large second-row penalty; limited recovery on broken JSON and nesting. |
| Reference solution (`gold_submit.py`) | Mid–Senior | 3–4 years | Robust parse + flatten + alias tables, careful timestamp handling, and emit-only-from-finalize architecture that maximises recovery without double-emitting. |

## 6. Skill map

**Primary skills trained**
- Streaming handler design (hold state, emit once in `finalize`)
- Tolerant JSON parsing and nested-field recovery
- Key alias maps and value normalisation (plans, emails, numbers)

**Secondary skills**
- Timestamp parsing across epoch and string formats
- Dedup / last-write-wins under at-least-once delivery

**Can be deferred on a first pass**
- Perfect recovery of every truncated or heavily broken line
- Exhaustive plan-alias tables beyond the main contract

## 7. Learning path
1. Fix the emit contract: never return rows from `process`; collect the best row per customer and emit only in `finalize`.
2. Add a recursive flatten + key-alias layer so nested and localized fields become visible.
3. Harden timestamp and email parsers, then re-score against the condition table in the README.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the CRM-migration problem, the intentional dirty-data patterns, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `handler.py` does wrong (especially double-emit), the concrete before/after code, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
