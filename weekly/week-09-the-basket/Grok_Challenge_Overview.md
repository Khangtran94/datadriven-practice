# Week 9 – The Basket: Challenge Overview

**One-sentence verdict:** Medium-hard SQL/DAG challenge (target 2–3 YoE) that forces as-of price joins, weight/quantity semantics, barcode normalization, and multi-source event vocabulary on a grocery-order finance table.

## Domain & context

Grocery delivery app. A customer orders items; a shopper scans them into bags; a driver delivers. Finance needs one clean row per order (status, delivered_at, items, subtotal, tip) for orders placed 2026-10-16 to 2026-11-14. Raw inputs are a short-lived order-events stream, a scan log that can be resent, and a nightly price snapshot that must be retained for historical as-of lookups.

## Core data-engineering problems

1. Events disappear after ~6 h — the pipeline must read frequently enough to capture every event of the day.
2. Prices change overnight; the price paid is the one current at order placement (as-of), not the latest list.
3. Items sold by the pound contribute 1 to the item count; the line total is weight × price-per-pound rounded to the cent.
4. Store labels (barcode starting with 2) embed the price in cents and do not appear on the price list.
5. UPCs appear as both 12-digit and 13-digit (leading-zero EAN-13) forms.
6. “2 for $5” shelf tags must be parsed to $2.50 each.
7. Tips arrive with `$` or `USD` suffixes; the last tip by customer event time is the one that counts.
8. Replacement decisions and cancellations/reinstatements must be resolved by the latest event of that type.

## Concepts you must master

| Concept | Why it appears |
|---------|----------------|
| As-of / temporal join | Price valid at `placed_at` |
| Incremental history tables | Events expire; full history must be retained |
| Barcode / identifier normalization | Leading zeros, store labels, order-id padding |
| Weight vs quantity semantics | Pound items count as 1 |
| String cleaning & type coercion | Tips, timestamps in multiple formats, NULL-as-text |
| Window ranking for “latest event” | Tips, replacements, cancel/reinstate |
| Dedup of resent daily files | Scans can be sent again whole |

## Difficulty & experience estimate

| Artifact | Level | Estimated YoE | Rationale |
|----------|-------|---------------|-----------|
| Problem statement (README) | Medium-hard | 2–3 | Many deliberate edge cases around pricing, barcodes, and late data |
| Your submission (`dag.sql`) | Medium | 1–2 | Solid cleaning and incremental structure; incomplete as-of pricing and weight/label logic |
| Reference solution (`gold_submit.sql`) | Hard | 3–5 | Compact but complete handling of every pricing, barcode, and event-vocabulary case |

## Skill map

- **Primary:** temporal joins, incremental history, string/barcode normalization, window “latest” logic  
- **Secondary:** multi-format timestamp parsing, quantity/weight rules, tip cleaning  
- **Can defer:** advanced DAG scheduling features beyond the given schedule

## Learning path

1. Build a small as-of price join on a toy history table and verify the price chosen for a given order timestamp.  
2. Write a barcode normalizer that strips leading zeros and extracts the embedded price from a type-2 label.  
3. Rank tip and replacement events by event time (not write time) and confirm the last value is selected.

## How this pairs with Grok_Analysis.md

Grok_Analysis.md shows the concrete SQL differences between `dag.sql` and `gold_submit.sql` (especially the subtotal/item-count calculation) with before/after snippets and example inputs. This overview explains why those differences exist in the grocery-finance domain.
