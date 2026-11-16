---
week: 9
folder: week-09-the-basket
title: The Basket
format: sql
domain: Retail / Grocery delivery - order basket billing
difficulty: 5
yoe_problem: 6-8
yoe_you: 4-6 (medium)
yoe_gold: 6-9
confidence_you: medium
score: 0.6682
rank: 2/5
analysis: yes
---

# Week 9: The Basket - Problem overview

SQL DAG · score 0.6682, rank #2 of 5 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A grocery delivery app takes an order, a shopper walks the aisles and scans each item into the bags, and a driver brings them to the door. Finance needs **1 clean row per order** placed from 2026-10-16 to 2026-11-14: whether it was delivered, how many items it charged, what they cost and the tip. Three raw tables feed it: `order_events` (a live table with a row each time an order is placed, changed or delivered, kept 6 hours), `scans` (the shopper app's log, 1 row per item scanned) and `prices` (a nightly snapshot of the stores' price list). You write the DAG. The hard part: the price an order paid is only in the copy of the price list that was current when it was placed, the order service forgets events after 6 hours, and each of the 3 apps writes numbers, times and words its own way.

## 2. Domain and real-world context

**Order-level billing for grocery delivery.** Finance reconciles every basket against what was actually scanned, priced at the time of the order, plus the shopper's tip. In real life this is daily work for data engineers at delivery apps: a transactional event table with a short retention, scanner logs from several app versions, price lists that change overnight, items sold by weight, store-printed labels that carry their own price, and corrections that arrive as whole days sent again.

## 3. Difficulty: 5/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 30 `[measured]` |
| Tasks in your DAG | 7 (3 normalize + 3 history + 1 final table) `[measured]`; the gold uses 4 (3 history + 1 final table) `[measured]` |
| Raw input tables | 3, from 3 systems `[measured]` |
| Output columns / expected rows | 6 columns; 17,036 rows, all built `[measured]` |
| Hard constraints | each task is 1 `SELECT`; events live 6 hours; the price list shows only today's prices `[measured]` |
| Hidden requirement | keep every copy of the price list and every copy of a resent day, then choose at read time `[inferred]` |

Why 5: it combines the history problem (events must be read at least every 6 hours, prices must be remembered), a money model (price per pound, store labels with the price inside, 2-for-$5 offers, ounces, take-backs) and a settling model (declined and approved replacements, cancels and reinstatements, the last tip by its own time). It is not harder because the README lists the conditions.

## 4. Problems the data throws at you

1. **Items sold by weight.** Weight times price per pound, rounded to the cent, and it is 1 item (91.1%). Hard because the quantity column is no longer the quantity.
2. **Prices change overnight.** The order pays the price in the copy current when it was placed (78.4%). Hard because the price list only shows today.
3. **Barcodes in other shapes.** A 0 in front of a UPC (70%), a store label starting with 2 that carries the price in cents (32%), order numbers typed with `#` (9%).
4. **Numbers as text.** Tips with `$` or `USD` (15%), a `2/5.00` offer (24.8%), weights in ounces (15.9%), a scan of `-1` (11.5%).
5. **Resent and late data.** A day sent again whole (29.2%), a scan the store took out (2.8%), a copy after the run began (15.5%), the same row twice (10%).
6. **Times in other forms.** Milliseconds and the phone's own offset (26%), a delivery saved on the phone for hours (13.3%), a tip synced late (5.4%).
7. **Each app's words.** `dropoff_complete`, `tip_updated`, `sub_rejected`, `canceled` (18%).
8. **Order life cycle.** Cancelled (5.9%), reinstated (2.1%), picked then called off (3.7%), events deleted before a run (62.1%).
9. **Price list gaps.** An item no longer sold (12.7%), a day with no price list (3.2%), a shelf find priced days later (4.6%).

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Incremental model + merge | Keep every distinct event, scan and price copy across runs | `incremental materialization`, `MERGE / upsert`, `unique key` |
| Short-retention source | Read the live table often enough that no event expires unread | `TTL`, `time to live`, `CDC` |
| As-of join | The price in force when the order was placed | `as-of join`, `slowly changing dimension type 2`, `lead() validity window` |
| Canonical keys | One spelling of a barcode and of an order number | `data normalization`, `surrogate key` |
| Replace vs merge | A resent day replaces the old one, it does not add to it | `full partition overwrite`, `idempotent load` |
| Latest-by-event-time | The last tip is the one set last, not the one written last | `row_number() over (partition by)`, `event time vs processing time` |
| Money in cents | Round each line once, then sum | `fixed-point arithmetic`, `banker's vs half-up rounding` |
| Defensive parsing | A bad value must give NULL, not fail the task | `try_cast`, `data quality checks` |

A short example of the barcode rule: one 12-digit form for UPC and EAN-13.
```sql
CASE WHEN length(d) = 13 AND substr(d, 1, 1) = '0' THEN substr(d, 2) ELSE d END
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **6-8 years** | medium | history with a retention limit, as-of price, replace-the-day semantics, settling of replacements, cancels and tips, 30 interacting conditions |
| Your code (`dag.sql`) | **4-6 years** | medium | normalize-then-history split with merge keys (L5-36), null markers cleaned in one pass (L76-135, L211-246), price validity intervals from change points (L482-497), declined replacements by latest reply (L471-479), latest tip by its own time (L462-469) |
| Gold code (`gold_submit.sql`) | **6-9 years** | medium | keeps every copy and chooses the newest load of each day (L105-115), digits-only keys with 13-to-12 digit fix (L127-132), vocabulary by `LIKE` on letters only (L44, L67-75), price taken as of the order with a first-price fallback (L147-154) |

- `dag.sql` has a sound structure. The gap to the gold is **how forgiving each parser is** and **which copy of a resent day it trusts**.
- Caveat: these numbers describe the level of the problem / the code, not a person. The gold is a top result, possibly refined against platform feedback, and it has blind spots of its own (see the analysis).

## 7. Common traps

- **A strict shape check on a number.** Sign: `regexp_like(qty, '^[0-9]+([.][0-9]+)?$')` on a column that also holds `-1`.
- **A strict shape check on a key.** Sign: `^[0-9]{1,8}$` on an order number that can start with `#`.
- **Different cleaning on the two sides of a join.** Sign: `pr.code = s.code` where one side may have a leading 0.
- **"First copy wins".** Sign: a filter like `batch_id NOT IN (SELECT batch_id FROM {{ this }})` on data that is corrected later.
- **A closed word list.** Sign: `IN ('delivered', 'order_delivered', ...)` with no `dropoff_complete`.
- **Digits taken out of an offer.** Sign: `regexp_replace(price, '[^0-9.]', '')` on `2/5.00`, which gives 25.00.
- **Newest row instead of newest event.** Sign: ordering tips by `written_at` first.

## 8. Mindset difference (you vs gold)

Your file builds every order, so its structure is right. The gold **keeps every copy and decides at read time**: a resent day is replaced by its newest copy, and every key and number is made canonical before it is joined. Your DAG accepts one spelling of each code, number and word, and trusts the first copy of a day, so an order is built but its `subtotal` is wrong 62% of the time. The specific lines, the Before/After code and the checklist are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** The price list has `036000291452` and the scanner reports `0036000291452` for the same item. How do you join them? *Hint: one canonical form before any join.*
2. **(mid)** A scale reports `20.32 oz` and the item costs 4.00 per pound. What is the line? *Hint: convert the unit first, then round to the cent once.*
3. **(senior)** The stores send a whole day again because 2 scans were never charged. Which copy do you keep, and how do you prove it? *Hint: the newest copy replaces the day; keep all copies so you can choose.*
4. **(senior)** An order is placed at 00:30, before the morning price list is published. Which price does it pay? *Hint: the copy that was current when it was placed, not the calendar day.*
5. **(senior)** A customer changes the tip on a phone with no signal and on the web. Which is the last tip? *Hint: order by when each was set, not when it was written.*
6. **(mid)** The source table deletes rows after 6 hours. How often must you read it? *Hint: at least every 6 hours, and keep your own history.*

## 10. Learning path

**Order of study:** (1) one canonical form per key and unit → (2) history and merge → (3) as-of price join → (4) replace-the-day versus merge → (5) settle replacements, cancels and tips onto an order.

**Exercise 1 - Barcode zoo (30-45 min).** Make a column with a 12-digit UPC, the same with a leading 0, a deli label and a 4-digit PLU. Turn each into one form. *Self-check:* the UPC pair gives 1 key and the deli label still starts with 2.

**Exercise 2 - Resent day (45 min).** Load a day of 10 scans, then load it again under a new stamp with 2 scans missing. *Self-check:* the day has 8 scans, and loading the second file twice changes nothing.

**Exercise 3 - Price as of the order (45 min).** A price list with 3 copies and 6 orders around the changes, 1 before the first copy. *Self-check:* each order gets 1 price and the early one takes the first price.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 9](https://datadriven.io/community/week-9)
