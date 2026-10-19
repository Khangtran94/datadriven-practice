---
week: 5
folder: week-05-the-close
title: The Close
format: sql
domain: Fintech / Payments - month-end close
difficulty: 4
yoe_problem: 5-7
yoe_you: n/a
yoe_gold: 6-9
confidence_you: low
score: 0.0000
rank: 11/13
analysis: yes
---

# Week 5: The Close - Problem overview

SQL DAG · score 0.0000, rank #11 of 13 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A card-payments company must close its books through 2026-10-12. Every night a job copies the day's changes from the production database into 3 "raw" tables (payments, FX rates, merchants), and the raw tables **keep only the few most recent copies**. Your job is to write a DAG that runs nightly (from 2026-09-18 to 2026-10-17) and builds `fct_payments`: exactly **1 row per payment**, 8 columns (status, amount in USD, amount settled, capture time, merchant country, ...). Each run sees only what the raw tables hold at that moment. The hard part is that the data is dirty in 33 different ways, and the past disappears unless you keep it yourself.

## 2. Domain and real-world context

**Fintech / Payments - financial close.** Finance uses this table to lock the month's figures: total paid out, money taken back, revenue per country. If a payment is counted twice, or money that moved after the cut-off lands in this period, the financial report is wrong, and correcting a number after the books are closed is expensive. In real life this is everyday work for data engineers at wallets, payment gateways and banks: late-arriving transactions, re-sent batches, many currencies, many time zones.

## 3. Difficulty: 4/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 33 `[measured]` |
| Tasks in the DAG | 4 (3 history + 1 final table) `[measured]` |
| Raw input tables | 3 `[measured]` |
| Output columns / expected rows | 8 columns / 99,261 rows `[measured]` |
| Hard constraints | each task is exactly 1 `SELECT`; nightly schedule; each run sees only the raw tables as they are then `[measured]` |
| Hidden requirement | you must keep the history yourself, because raw forgets `[inferred]` |

Why 4: many conditions interact (for example a late FX rate × a payment created on a weekend × several currencies), plus a design requirement about time that the task never states. It is not 5 because the README gives no hard resource limit (only a "work per raw row" score). It would be one level harder if the column formats were not described and the README did not list the conditions.

## 4. Problems the data throws at you

1. **History disappears (the hidden requirement).** Raw keeps only recent copies, so "the final state of a payment" and "which country the merchant was in at the time" must be carried over from earlier nights. Example: a merchant moves from VN to TH and the raw table afterwards shows only TH. Hard because nothing in the task says "keep history".
2. **One payment, many copies.** The same payment appears on several nights (58%), some rows are written twice (35%), an old batch is loaded again (25%), a hand-fixed row has the same timestamp (16%). The newest row may lack columns that an older row has (45%). Hard because "take the latest row" loses data.
3. **Money: units, currencies, several payouts.** The smallest unit of JPY is 1 and of KWD is 1/1000; some rows hold decimals instead of minor units; rates exist only on business days and are sometimes published wrongly and then published again; a payment is paid out over several nights, with negative nights for refunds. Hard because one wrong step breaks the whole amount column.
4. **Time and late data.** The same instant is written 3 ways, epoch seconds or milliseconds sit in a text column, some times carry a +05:30 offset; a night's copy can land after the 03:00 morning run, and a rate can land after the run. Hard because comparing times as text gives silently wrong answers.
5. **Dirty text.** NULL is written as a word ("NULL", "\N", "N/A"), ids lose leading zeros or change case, statuses vary in case and use another gateway's words, a JSON key is camelCase, and JSON is cut off by the column width. Hard because **one broken JSON value is enough to crash the whole task**.
6. **Merchants change over time.** A merchant changes country, goes from test to live, or disappears from the source; one night's merchant copy never arrives. Hard because you need "the value on the payment's day", not today's value.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Incremental model + merge | Keep every row seen across nights, without adding duplicates on a rerun | `incremental materialization`, `MERGE / upsert`, `unique key` |
| Idempotency | Rerunning a night gives the same result | `idempotent pipeline`, `rerun`, `backfill` |
| History table / SCD | Store the states of merchants and payments over time | `slowly changing dimension type 2`, `snapshot` |
| As-of (point-in-time) join | The FX rate / merchant that was valid **on the payment's day** | `as-of join`, `lead() validity window`, `point-in-time correctness` |
| Dedup with window functions | Choose one row per key | `row_number() over (partition by)`, `qualify` |
| Newest non-null per column | Each column takes its latest non-empty value | `coalesce last`, `last_value ignore nulls` |
| Late-arriving data | A state or a rate arrives after the run | `late arriving facts`, `event time vs processing time` |
| Defensive parsing | Parsing must never crash the whole task | `json_valid`, `try_cast`, `data quality checks` |
| Currency minor units (ISO 4217) | Divide by 1 / 100 / 1000 depending on the currency | `ISO 4217 minor units`, `currency exponent` |
| Orchestration | Task order and run conditions | `depends_on`, `trigger rule all_done`, `DAG` |

A short example for the as-of join: Friday's rate stays valid until a new rate appears, so a Saturday payment uses Friday's rate.
```sql
lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day  -- valid while rate_day <= day < next_day
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **5-7 years** | medium | persistent history + idempotent merge, as-of join, late-arriving data, and 33 kinds of dirty data at once |
| Your code (`dag.sql`) | **not enough evidence** | low | 40 lines, 4 `SELECT`s, looks close to an unmodified starter skeleton: `SELECT *`, `NULL AS merchant_country`, template-style comments (L19, L40) |
| Gold code (`gold_submit.sql`) | **6-9 years** | medium | merge + `unique_key` + `trigger_rule` (L7-22), guarded parsing (L27-78), as-of join with `lead()` (L248-285), median-based rate sanity check (L236-247) |

- I did not rate the level from `dag.sql`, because I cannot tell whether it is your own work or only the starter template `[inferred]`. The one positive thing visible is that the tasks and their `depends_on` links are wired in the right order. If you wrote this file yourself, tell me and I will rate it again.
- The gap is not a number of years but three specific skills: guarding parsing, keeping history over time, and joining on the valid-on-that-day row.
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined over many submissions against platform feedback or written with tooling (long, repetitive CASE blocks look generated).

## 7. Common traps

- **Trusting raw as the final source of truth.** Sign: the final table reads straight from raw, with no history table.
- **Running a parse function without a guard.** Sign: `json_extract` / `CAST` directly on a text column; one bad row crashes the task and every condition shows 0%.
- **Taking "the latest row" instead of "the latest value per column".** Sign: `row_number() = 1`, then a column that was empty in the newest row is lost.
- **Joining FX on the exact date.** Sign: weekend payments have no rate.
- **Counting money twice.** Sign: total `settled` is larger than reality when a night is sent again.
- **Ordering times as text.** Sign: `03:30+05:30` sorts after `01:00+00`.
- **Assuming every currency divides by 100.** Sign: JPY / KWD are off by 100x or 10x.
- **Asking "was this merchant ever a test?" instead of "was it a test on the payment's day?"**

## 8. Mindset difference (you vs gold)

Your file treats each run as "read raw, write output". The gold treats raw as a temporary landing area, **builds its own history**, and answers every "as of that day" question from that history. The gold is also designed so that one bad row cannot kill the whole pipeline. The specific bugs, the Before/After code and how to verify are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** The raw table keeps only the last 3 days but you need the whole month. How do you design it? *Hint: an incremental history table, merged on a row key, independent of raw.*
2. **(mid)** FX rates exist only on business days but payments happen every day. How do you join? *Hint: as-of join, give each rate an end date with `lead()`.*
3. **(senior)** How do you make a rerun of one night create no duplicate rows and no double-counted money? *Hint: idempotent merge, plus one value per (payment, night) instead of accumulating.*
4. **(senior)** A state arrives 3 days late, after you already wrote the figures. How does an append-only table cope? *Hint: recompute from history every run; do not "append and forget".*
5. **(senior)** When do you use `trigger_rule: all_done`, and what is its risk? *Hint: the final table is still built when an upstream task fails; the risk is a silently incomplete result, so add quality checks.*
6. **(mid)** The same money column holds both `12.50` and `1250`. How do you handle it, and what is the risk? *Hint: detect by the decimal point, but confirm the rule with the data owner.*

## 10. Learning path

**Order of study:** (1) safe parsing → (2) newest row / newest value → (3) as-of join → (4) incremental + merge + idempotency.

**Exercise 1 - Parsing that never crashes (30-45 min).** Create a 6-row table with valid JSON, cut-off JSON, `''`, `'NULL'`, `'-'`. Write a CTE that extracts `order_ref`. *Self-check:* it runs without error, returns the value where it can be read, and `NULL` elsewhere.

**Exercise 2 - Newest value per column (45 min).** 3 rows for one payment, the newest row leaves `amount` empty. Use `max(time_key || value)` for each column. *Self-check:* `status` comes from the newest row, `amount` from an older row.

**Exercise 3 - As-of join (45 min).** An FX table with Monday-Friday only and 5 payments spread across a week. *Self-check:* Saturday and Sunday payments use Friday's rate; add a corrected rate for the same day and the later one wins.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 5](https://datadriven.io/community/week-5)
