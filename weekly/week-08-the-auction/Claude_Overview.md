---
week: 8
folder: week-08-the-auction
title: The Auction
format: sql
domain: Advertising / Search ads - pay-per-click auction billing
difficulty: 5
yoe_problem: 6-8
yoe_you: 4-6 (medium)
yoe_gold: 6-9
confidence_you: medium
score: 0.8416
rank: 3/8
analysis: yes
---

# Week 8: The Auction - Problem overview

SQL DAG · score 0.8416, rank #3 of 8 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A search engine sells the few ad slots above and below its results, one auction per search, and the advertiser pays only when someone clicks. The inventory team needs **1 clean row per ad shown**: whose it was, where it sat, whether it was clicked and what it billed. Each night a job copies 2 raw tables out of 2 systems: `ad_events` (the ad server's log, with a row for every ad shown, every click and every verdict of the click-fraud filter) and `accounts` (billing's nightly snapshot of the open advertiser accounts). You write the DAG that builds the table of ads shown from **2026-10-09 to 2026-11-07**; billing's month ended 2026-10-31. The hard part: the ad, its clicks and its verdicts are separate rows written by 3 different programs, the log keeps only a few days, and the day an ad belongs to depends on the account's own time zone.

## 2. Domain and real-world context

**Pay-per-click search advertising (cost per click).** Inventory and billing teams need ads shown, position (slot), clicked or not, and the amount billed. In real life this is daily work for data engineers at ad platforms: impression, click and invalid-traffic logs written by different services, prices kept in micros so no currency needs a fraction, a fraud filter that revises its verdicts for days, account time zones that decide which day an ad belongs to, and a month that closes on the account's calendar while verdicts keep arriving.

## 3. Difficulty: 5/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 30 `[measured]` |
| Tasks in your DAG | 5 (4 incremental history/version tasks + 1 final table) `[measured]`; the gold uses 4 (2 history + 2 tables) `[measured]` |
| Raw input tables | 2, from 2 systems `[measured]` |
| Output columns / expected rows | 7 columns; 170,216 expected rows `[measured]` (your DAG built 157,679) |
| Hard constraints | each task is 1 `SELECT`; the log keeps only a few days; billing's copy is missing on some mornings and on the last one `[measured]` |
| Hidden requirement | keep your own history of both tables, and use the account's time zone **as it was on the day of the ad** `[inferred]` |

Why 5: the history problem of weeks 5 to 7 is here, plus a money model (micros, 2-click cap, invalid clicks not billed, month-close credits), a time-zone model with clock changes and an account that moves east, and a verdict model (latest by its own time, resent old verdicts, verdicts after the log forgot). It is not harder than 5 only because the README lists the conditions.

## 4. Problems the data throws at you

1. **Ids in several spellings.** Base64 with `=` padding (5%), base64url with `-` and `_` or percent-encoded `%2B` `%2F` on clicks (45%). Hard because the same impression becomes 2 keys unless every id is made canonical.
2. **3 programs, 4 vocabularies.** `impression`, `CLICK`, `IVT` and `reinstated` for the same log column (16%). Hard because nobody mapped one vocabulary onto another.
3. **Times in other forms.** Microseconds, milliseconds, ISO text and California time with the day's offset (18%). Hard because text sorts wrongly, so the first click and last verdict are picked wrong.
4. **Prices in units of money.** `850000` micros against `0.85` or `45` yen (30%). Hard because a micros column read as is bills a millionth of the price.
5. **Slots named the old way.** `ML2`, `mainline-2`, `B1` (14%). Hard because the old build's names must map onto `top-N` and `bottom-N`.
6. **The account's day, not UTC's.** Evening ads in California are next morning in UTC (20%), clocks change mid-month (1.2%), an account can move east once (0.7%). Hard because a fixed offset puts an ad near midnight on the wrong day.
7. **Late and repeated loads.** A copy after the run began (17.4%), Asia's file after the run (7.8%), a day's rows sent again (8%), the same row twice (16%). Hard because a watermark never comes back for them.
8. **Billing rules.** At most 2 clicks per ad, repeat clicks priced 0, clicks refused on the spot, the latest verdict wins, an old verdict sent again (60% of tables), a verdict after the month closed is a credit next month. Hard because "newest row" and "newest verdict" differ.
9. **Account gaps.** Ids with dashes (14%), ids short of their leading 0 (60%), no account table that run (13.4%), an account that left or opened mid-month. Hard because the join to billing finds nothing unless history is kept.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Incremental model + merge | Keep every distinct event and account snapshot across nights without duplicates on a rerun | `incremental materialization`, `MERGE / upsert`, `unique key` |
| Late-arriving data | Take rows again whose load stamp is not newer than the last one read | `watermark`, `lookback window`, `idempotent load` |
| Canonical keys | One spelling of an id for serves and clicks | `base64url`, `URL decoding`, `surrogate key` |
| As-of join | The account version in force on the day of the ad | `as-of join`, `slowly changing dimension type 2`, `lead() validity window` |
| Time zones and clock changes | Local day of an ad, month end on the account's calendar | `AT TIME ZONE`, `DST transition`, `business date` |
| Dedup with window functions | One row per key with a tie-break | `row_number() over (partition by)` |
| Settling events onto one row | Click and verdicts attached to the ad | `conditional aggregation`, `first_value`, `last_value` |
| Money in minor units | Micros, decimals, currencies without fractions | `fixed-point arithmetic`, `micros` |
| Defensive parsing | A bad value must give NULL, not fail the task | `try_cast`, `data quality checks` |

A short example of the id rule: make serve and click ids meet on one canonical key.
```sql
REPLACE(REPLACE(REPLACE(REPLACE(RTRIM(id, '='), '%2B', '+'), '%2F', '/'), '-', '+'), '_', '/')
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **6-8 years** | medium | history + idempotent merge for 2 tables, as-of account zone, clock-change-aware month close, verdict resolution, 30 interacting conditions |
| Your code (`dag.sql`) | **4-6 years** | medium | keyed history that survives the log window (L47-72, L134-228), account versions as validity intervals with a first-version fallback (L261-291), early null-marker clean (L76-90, L136-156), 2-click cap and latest verdict by time (L293-337) |
| Gold code (`gold_submit.sql`) | **6-9 years** | medium | `unique_key` merge with a same-stamp lookback (L8, L13, L182-185), inline zone table with clock-change dates (L499-750), packed sort keys carried through `max` for the newest non-null value, verdict windows closed at the account's month end |

- `dag.sql` already keeps both histories and picks the account version in force, so its structure is sound. The gap to the gold is **coverage of shapes**: id spellings, slot names, price units, ISO verdict times and the date window.
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined against platform feedback or generated (long repeated `CASE` blocks), and it has blind spots of its own (see the analysis).

## 7. Common traps

- **One strict shape check on a key.** Sign: `length(id) = 22 AND regexp_like(id, '^[A-Za-z0-9+/]{22}$')` on an id that also arrives padded or base64url.
- **Integer cast on a price.** Sign: `CAST(CAST(detail AS INTEGER) AS VARCHAR)` on `0.85`, which gives 0.
- **Closed vocabulary lists.** Sign: `IN ('top-1','top1', ...)` with no `ML2` or `mainline-2`.
- **No window on the output.** Sign: a final `SELECT` with no `WHERE` on the requested dates, so out-of-window ads appear as unmatched rows.
- **Times left as NULL.** Sign: only 10-, 13- and 16-digit numbers are read, so ISO verdicts lose their time and never win.
- **Newest event instead of newest verdict.** Sign: invalid counts only when it is the latest event of any kind.
- **Ignoring the month close.** Sign: a verdict after the account's month end zeroes the bill instead of becoming next month's credit.
- **Reading only tonight's file.** Sign: a watermark filter on `_loaded_at`, so Asia's late file never comes back.

## 8. Mindset difference (you vs gold)

Your file keeps history and uses the version in force, and it avoids the late-file trap by merging every night over the whole window. The gold also **makes every key and time canonical first** (one id form, one time parser, one price rule), and only then ranks and joins. Your DAG accepts one spelling of the id, the price and the slot, so an ad is built but wrong, or lost. The specific bugs, the Before/After code and the measured effect are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** The same impression arrives as `AbC+/x==` on the serve and `AbC-_x` on the click. How do you join them? *Hint: one canonical form of the id before any join.*
2. **(mid)** A legacy path logs a price as `0.85` and the main path as `850000`. How do you store both? *Hint: micros as integers, decide the unit per shape, never cast a decimal to integer.*
3. **(senior)** An ad is shown at 23:30 in California. Which day is it, and what if the account moves time zone next week? *Hint: as-of join to the account version in force, convert to local time, keep every snapshot.*
4. **(senior)** The fraud filter flags a click, then clears it, then resends the first verdict. What is billed? *Hint: the latest verdict by its own time, not by arrival order.*
5. **(senior)** A verdict lands after the month closed. Does it change the invoice? *Hint: no, it is a credit on the next one; close the month on the account's calendar.*
6. **(mid)** The log keeps 3 days and an export lands after the morning run. How do you not lose it? *Hint: rebuild from your own history with a lookback, not a watermark.*

## 10. Learning path

**Order of study:** (1) one canonical rule per key and unit → (2) history and merge → (3) as-of account zone → (4) settle clicks and verdicts onto an ad.

**Exercise 1 - Id zoo (30-45 min).** Make a column with `AbC+/x`, `AbC+/x==`, `AbC-_x`, `AbC%2B%2Fx`. Turn every value into one form. *Self-check:* all 4 give the same key and bad input gives NULL.

**Exercise 2 - Account zones (45 min).** 3 daily account snapshots, one where the zone changes. Join 10 ads, some near midnight, to the zone in force. *Self-check:* each ad picks 1 snapshot and the local date flips correctly across a clock change.

**Exercise 3 - Settle a click (45 min).** One ad with 3 clicks (one priced 0), a flag, a clearing, an old flag sent again and a verdict after month end. *Self-check:* clicked is 1, at most 2 clicks are billed, the latest verdict before the month close decides.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 8](https://datadriven.io/community/week-8)
