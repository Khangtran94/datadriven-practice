# Week 5 – The Close: Challenge Overview

## 1. One-sentence verdict
This is a hard production-style incremental + book-close challenge for a data engineer with roughly 3–5 years of experience in payments / fintech data platforms.

## 2. Domain & context
- **Simulated business**: a card-payments company closing its books.
- **Pipeline goal**: produce one clean row per payment for Finance, covering the window 2026-09-18 → 2026-10-17 (close through 2026-10-12).
- **Raw inputs**: three nightly copy tables (`raw_payments`, `raw_fx_rates`, `raw_merchants`) that keep only recent batches. Each night’s extract can be late, duplicated, partially rewritten, or missing. The landing zone does not retain history forever, so the DAG must be incremental and correct under incomplete visibility.

## 3. Core data-engineering problems
The README deliberately injects the following production realities (ordered roughly by frequency/impact):

1. **Multi-night history of the same payment** – a payment appears once per night it changed; Finance wants the final state, not every intermediate row.
2. **Exact duplicate rows inside a single batch** – restarted loads write the same logical row twice.
3. **Payouts split across nights** – settled amounts must be summed, not taken from the last row only.
4. **Late-arriving batches** – a night’s copy lands after the morning run has already started (or even days later).
5. **Missing FX rates on non-business days** – Saturday/Sunday payments need the last published rate.
6. **Last row lacks older fields** – dispute/capture updates only write the columns they own; naïve “newest row wins” drops amount, merchant, etc.
7. **Null-as-text, mixed status vocabulary, epoch vs ISO timestamps, 0- and 3-decimal currencies, major-vs-minor units, truncated/camelCase JSON, merchant moves and test flags**, and several other dirty-data patterns.

The scoring harness penalises both missing rows and extra rows for the same payment key.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Incremental model + merge on a stable row key | History tables must upsert corrections and re-sent days instead of appending forever. |
| Effective / batch dating | `_batch_id`, `_correction_for` and load time determine which night a row belongs to. |
| Last-non-null collapse (per payment) | Newest row is often incomplete; older attributes must be carried forward. |
| As-of / point-in-time join | FX rate and merchant country must be the values that were true on the payment’s created day. |
| Multi-currency minor-unit handling | JPY/KRW (0 dp), KWD/BHD (3 dp), and the long tail of ISO 4217 currencies. |
| Tolerant parsing | Null markers as text, epoch seconds/ms, local offsets, truncated JSON, camelCase keys. |
| Test-merchant filtering & SCD-style merchant attributes | Merchants change country / go live; test traffic must be excluded. |
| Period-bounded aggregates | `settled_in_period_usd` must ignore money that moved after the close window. |
| DAG orchestration details | `incremental_strategy: merge`, `unique_key`, `trigger_rule: all_done`. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3–4 years | Dozens of realistic dirty-data and late-data conditions; requires incremental design, as-of logic and defensive parsing. |
| Your submission (`dag.sql`) | Junior | ~1 year | Bare `SELECT *` history tasks, no cleaning, no merge key, naïve fact projection that crashes on dirty JSON / types. |
| Reference solution (`gold_submit.sql`) | Senior+ | 5+ years | Full production defensive style: stable `rk`, merge, timestamp normalisation, last-non-null, median-guarded FX, truncated-JSON recovery, correct minor-unit math, as-of merchant lookup. |

## 6. Skill map

**Primary skills trained**
- Designing incremental history tables with a correct unique key
- Collapsing multi-version payment history into one finance-ready row
- As-of joins for rates and slowly-changing merchant attributes
- Robust type/null/timestamp/JSON cleaning at scale

**Secondary skills**
- Multi-currency amount normalisation
- Period-aware settled-amount calculation
- DAG trigger and dependency semantics

**Can be deferred on a first pass**
- Perfect recovery of every exotic status spelling or edge-case JSON
- Micro-optimisations of the ranking key

## 7. Learning path
1. Re-implement the three history tasks so they emit a stable `rk`, normalised timestamps, and clean typed columns (null-as-text → NULL, status vocabulary, merchant_id padding, etc.).
2. Add `incremental_strategy: merge` + `unique_key: [rk]` and make `fct_payments` survive with `trigger_rule: all_done`.
3. Build the fact table with last-non-null collapse, as-of FX and merchant joins, correct minor-unit divisors, and the settled-in-period window. Only then compare row counts and column accuracy against the gold numbers.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `dag.sql` does wrong, the concrete before/after SQL, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
