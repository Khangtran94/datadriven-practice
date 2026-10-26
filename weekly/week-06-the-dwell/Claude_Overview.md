---
week: 6
folder: week-06-the-dwell
title: The Dwell
format: sql
domain: Logistics / Container terminal - storage billing
difficulty: 5
yoe_problem: 6-8
yoe_you: 4-6 (medium)
yoe_gold: 6-9
confidence_you: medium
score: 0.6853
rank: 3/5
analysis: yes
---

# Week 6: The Dwell - Problem overview

SQL DAG · score 0.6853, rank #3 of 5 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A container terminal bills shipping lines for every day a container sits in its yard, and billing needs **1 clean row per visit** (a container's stay from ship to gate). Every night a job copies 3 raw tables out of 2 source systems: `unit_visit` (a change log, one row for each visit that changed or was charged that night), `line_operator` (a nightly snapshot of the shipping lines) and `tariff_rate` (a rate table sent in full on the first night, then only changes). You write the DAG that builds `storage_charges`, 8 columns, for the period ending **2026-10-19**, from the nightly loads between 2026-09-25 and 2026-10-24. The hard part: the raw tables forget (unit_visit keeps 7 nights, tariff 2, the line copy only the latest), the data is dirty in 34 listed ways, and the money depends on **which day each charge fell on and which rate was in force that day**.

## 2. Domain and real-world context

**Logistics / port operations - storage (dwell) billing.** A container that stays in the yard past its free days is charged per day. Billing sends the invoice to the shipping line (or its local agent), so the table must say how many days were charged, at which rate, and **who is billed on the day the box came off the ship**. In real life this is everyday work for data engineers in terminal operating systems: late-arriving loads, days waived after disputes, hand-fixed rows that bypass the application, tariffs that change while boxes are still in the yard, and two systems writing the same column in different vocabularies.

## 3. Difficulty: 5/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 34 `[measured]` |
| Tasks in your DAG | 4 (3 history + 1 final table) `[measured]`; the gold uses 9 (3 history + 6 tables) `[measured]` |
| Raw input tables | 3, from 2 source systems `[measured]` |
| Output columns / expected rows | 8 columns; 48,948 expected rows `[measured]` (your DAG built 43,311) |
| Hard constraints | each task is exactly 1 `SELECT`; nightly schedule; each run sees only the raw tables as they are then `[measured]` |
| Hidden requirement | keep the history yourself (raw forgets) and total the days **by charge day**, not from a running total `[inferred]` |

Why 5: it has week 5's history problem and adds a money model with several layers: days charged per night, restated days that replace earlier ones, negative days when charges are waived, a rate that changes mid-stay, a 06:00 terminal-day cutoff, and a billing party that depends on the day. Many conditions interact (a restated day × a late batch × a rate change). It is not harder than 5 because the README lists the conditions.

## 4. Problems the data throws at you

1. **One visit, many copies and many states.** A visit appears on every night it changed or was charged (86.7%); a night is loaded twice (35%); an old window is run again by hand and lands in a newer batch (25%). The newest row is missing fields (45%). Hard because "take the latest row" loses data and load order does not mean recency.
2. **Money is a sum over days, not a field.** Each night holds only that night's days; the invoice is the total, so every night must be counted once. A restated day replaces the earlier copy (18%), days can be negative after a waiver (3.5%), and days are charged after the close (30.7%). Hard because adding twice or never reading a night both give a wrong total.
3. **Rates change during the stay.** The days before the effective day use the old rate and the days from it use the new one; a rate published wrongly is published again for the same day (3.8%). Hard because you need the rate of each day, not today's rate.
4. **Time.** The same instant appears as epoch seconds or milliseconds in text, with a sender's offset, with no zone (port time, UTC+8), or in 3 UTC spellings; the terminal day is cut at 06:00, so 07:00 port time belongs to that day while UTC is still the day before. Hard because comparing times as text sorts wrongly and a wrong day changes who is billed.
5. **Keys and codes.** Visit keys come with leading zeros or spaces (5%), box numbers with spaces, hyphens or lower case (18%), one system has no check digit (5%), line codes are cased or padded. Hard because one visit can end up under two keys.
6. **Two vocabularies in one column.** The gate app's own state words (landed, on_hold, delivered, restowed) sit beside the yard's. Hard because nobody mapped one onto the other.
7. **The line side changes.** A line changes its billing agent, merges into another and disappears, is a test line at first, or a night's copy comes back empty. Hard because the landing keeps only the latest copy, so history must be stored by you.
8. **Dirty text.** NULL written as a word (30%), blank refs holding text, camelCase JSON keys (12%), JSON cut by the column width (0.6%) so a JSON function raises and takes the whole task with it.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Incremental model + merge | Keep every distinct source row across nights without duplicates on a rerun | `incremental materialization`, `MERGE / upsert`, `unique key` |
| History / snapshot table | Store the state of a shipping line (bill-to, test flag) per night | `slowly changing dimension type 2`, `snapshot` |
| As-of (point-in-time) join | The rate or billing party valid **on the day** | `as-of join`, `lead() validity window` |
| Newest non-null per column | Each column takes its latest non-empty value | `last_value ignore nulls`, `coalesce last` |
| Dedup with window functions | One row per key, with a tie-break rule | `row_number() over (partition by)` |
| Restatement / correction handling | A re-sent day replaces the day, it is not added | `restated`, `bitemporal data`, `late arriving facts` |
| Aggregate by event day | Total days by charge day, not from a running total | `conditional aggregation`, `sum(case when)` |
| Time zones and business day cutoff | 06:00 shift change defines the terminal day | `AT TIME ZONE`, `business date` |
| Defensive parsing | Parsing must never crash the whole task | `json_valid`, `try_cast`, `data quality checks` |
| Check digit (ISO 6346) | Compute the 11th character of a box number from the first 10 | `container check digit`, `ISO 6346` |

A short example for the as-of join on the terminal day: shift the UTC clock by 2 hours so the day changes at 06:00 port time.
```sql
date(dsch_utc, '+2 hours') AS terminal_day   -- 07:00 port time (23:00 UTC) belongs to the next day
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **6-8 years** | medium | history + idempotent merge, restatement logic, as-of rate windows, day-level money, 34 interacting dirty-data conditions |
| Your code (`dag.sql`) | **4-6 years** | medium | window dedup and `LEAD()` rate windows (L688-707), as-of interval join (L798-805), forward-fill by running sum (L759-781), one-sort rank trick with fixed-width key (L646-664), early ingestion filters (L80-94) |
| Gold code (`gold_submit.sql`) | **6-9 years** | medium | merge + `unique_key` (L7-48), fixed-width sort keys carried through `max` (L250-264), restated day wins over the rows it restates (L314-326), integer ten-thousandths pricing (L331-348) |

- `dag.sql` shows real design work: you already reduced repeated sorts and chose interval joins instead of correlated subqueries (comments at L631-635, L797). The gap to the gold is not structure but **coverage of dirty data**: key shapes, timestamp forms, null markers, number formats.
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined against platform feedback or generated (repeated long `CASE` blocks).

## 7. Common traps

- **Validating a key shape too tightly.** Sign: `length(key) = 8`; every visit with another spelling is dropped and all its columns are lost.
- **Accepting only some timestamp forms.** Sign: a branch for `Z` and `+HH:MM` only; `+0530`, `+08` and ` UTC` become NULL, and the "newest" row is chosen wrongly.
- **Taking the newest row instead of the newest value per column.** Sign: `event_rank = 1` for a column the gate app leaves empty.
- **Treating null markers differently in each column.** Sign: `NULLIF(col, '')` on a code used in a join; `\N` becomes a tariff code that matches no rate.
- **Parsing days as integers.** Sign: `CAST(days AS INTEGER)` after a pattern that rejects `1.5`.
- **Rounding every day to cents.** Sign: `ROUND(days * rate * 100)` per row, then summing; the gold sums in ten-thousandths and rounds once.
- **Joining the billing party on a day that can be NULL.** Sign: the as-of join compares a column with no fallback day.
- **Asking "was this line ever a test?" instead of "was it a test on that day?"**

## 8. Mindset difference (you vs gold)

Your file is organized and efficient, and it already treats raw as temporary. The gold also builds its own history, but it **cleans every column in the same defensive way first** (same null markers, same time parser, same key rules) and only then ranks and joins. Your DAG validates some columns strictly and others loosely, so the same visit is clean in one column and lost in another. The specific bugs, the Before/After code and the measured effect are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** Each night's row holds only that night's charged days. How do you get the invoice total without double counting a night that was loaded twice? *Hint: dedupe by (visit, charge day), then sum.*
2. **(mid)** A box came off the ship at 07:00 port time on the 3rd, which is the 2nd in UTC. Which day is it billed on? *Hint: shift the clock by the cutoff before taking the date.*
3. **(senior)** A rate changes while boxes are in the yard. How do you price each day? *Hint: effective-day windows with `lead()`, join on `day >= effective and day < next`.*
4. **(senior)** An old window is re-run by hand and lands in a newer batch. How do you stop it overwriting newer data? *Hint: rank by a business time (update time, batch day), not by load order.*
5. **(senior)** Commercial waives days after a dispute, so a night can be negative. What breaks if you total from the last night's row? *Hint: total from all charge days, signed.*
6. **(mid)** A line merges into another and disappears from the live table while its boxes are still in the yard. Where do you get its billing party? *Hint: keep your own history of the snapshot.*

## 10. Learning path

**Order of study:** (1) one cleaning rule for every column → (2) newest value per column → (3) day-level totals with restatement → (4) as-of rate and party joins.

**Exercise 1 - One cleaning rule (30-45 min).** Make a text column with `'NULL'`, `'\N'`, `' '`, `'N/A'`, `'-'`, `'x'`. Write one CASE that turns every marker into NULL and reuse it for 3 columns. *Self-check:* the same input gives the same result in every column.

**Exercise 2 - Timestamp zoo (45 min).** Rows with `2026-10-01 03:30:00+0530`, `...+08`, `... UTC`, `...Z`, epoch seconds, epoch ms, and no zone (port time). Convert all to `YYYY-MM-DDTHH:MM:SSZ`. *Self-check:* no NULL except truly bad input, and sorting the result as text matches real time order.

**Exercise 3 - Charge days (45 min).** One visit, 4 nights, one restated day, one negative day, a rate change on day 3. *Self-check:* the total equals the hand-computed sum, rerunning a night changes nothing, and the part up to the close date is smaller than the total.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 6](https://datadriven.io/community/week-6)
