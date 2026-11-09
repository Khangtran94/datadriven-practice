# Week 8 – The Auction: Challenge Overview

**One-sentence verdict:** High-difficulty (3–5 YoE) production-grade SQL DAG problem in ad-tech inventory: normalize multi-source event logs with messy timestamps, IDs, vocabularies and late verdicts, then produce one clean billed impression row per ad under account-local calendars and month-close rules.

## Domain & context

A search engine sells a handful of ad slots above and below organic results via real-time auction. Advertisers are charged only for clicks (CPC). The inventory team needs a single reliable row per ad that was shown: the advertiser, the slot, the exact serve instant, the local calendar day, whether it was clicked, and the billed amount in micros. Two raw sources are copied nightly:

- `ad_events` — append-only log of serves, clicks and fraud-filter verdicts (multiple writers, different clocks, vocabularies and encodings; only last three nights retained).
- `accounts` — nightly snapshot of open advertiser accounts (time zone + currency); only the latest copy is kept by the source system.

The DAG must materialize the target `ad_impressions` for the window 2026-10-09 through 2026-11-07 (billing month closed 2026-10-31). Incremental / history tables are required because late-arriving Asia files, re-copies, and verdicts that arrive days later must still be applied correctly.

## Core data-engineering problems

1. **Multi-vocabulary event typing** — three independent systems write “impression”, “CLICK”, “IVT”, “reinstated”, etc.; must map onto serve / click / invalid / valid.
2. **Heterogeneous timestamps** — microseconds, milliseconds, seconds, ISO strings, California local with offset, packed numeric forms; must all become comparable UTC epochs.
3. **Impression-ID normalization** — base64 with optional `=` padding, base64url (`-`/`_`), percent-encoding (`%2B`/`%2F`); same 16-byte ID must match across serve and click.
4. **Account-ID cleaning & as-of time zone** — dashes, leading-zero loss, mid-month opens/closes, eastward zone moves; zone in force on the serve day must be recovered from historical snapshots.
5. **Slot canonicalization** — legacy “mainline-2”, “ML2”, “B1” → `top-2` / `bottom-1`; only valid top-1..4 / bottom-1..3 survive.
6. **Price unit conversion** — micros, decimal currency units, yen integers; first two priced clicks only, third ignored.
7. **Fraud & month-close logic** — latest verdict before the account’s month closed wins; post-close invalidations become credits (not this month’s bill); clicked flag is independent of billability.
8. **Late data, duplicates & retention** — same row re-copied, Asia files after watermark, verdicts after the click left the 3-night window; must keep history and re-process.

## Concepts you must master

| Concept | Why it appears |
|---------|----------------|
| Incremental merge + history tables | Late-arriving files, re-copies, and post-retention verdicts |
| Robust string / timestamp parsing | 3+ timestamp formats + NULL-as-text + URL encodings |
| As-of / interval joins on snapshots | Account zone valid on the exact serve instant |
| Windowed ranking & conditional aggregation | First two clicks, latest pre-close verdict |
| Time-zone-aware date arithmetic | Account-local served_date and month boundaries |
| Deduplication with stable keys | Exact same event under different load stamps |
| Defensive null / sentinel cleaning | 50 % of rows have textual “null”, “n/a”, etc. |

## Difficulty & experience estimate

| Artifact | Level | Estimated YoE | Rationale |
|----------|-------|---------------|-----------|
| Problem statement (README) | Hard | 3–5 | Multi-source vocabulary, as-of zones, month-close credits, late data, ID encodings |
| Your submission (`dag.sql`) | Intermediate | 2–3 | Solid cleaning & history skeleton; incomplete parsers, missing URL/base64url, no month-close, weaker slot/time handling |
| Reference solution (`gold_submit.sql`) | Expert | 5+ | Full defensive timestamp parser, zone-offset table, pre-close verdict windows, partner/adtest filters |

## Skill map

- **Primary:** incremental DAG design, multi-format timestamp/ID normalization, as-of joins, windowed “first-N + latest-before-cutoff” logic.
- **Secondary:** time-zone offset tables, price unit conversion, sentinel-value cleaning.
- **Can defer:** pure analytical functions once the core join/window patterns are solid.

## Learning path

1. Extract and unit-test a single pure function that turns every timestamp shape in the README conditions into a UTC epoch.
2. Build the impression-ID normalizer (strip padding, base64url → standard, percent-decode) and verify serve/click matching.
3. Implement the account as-of join + zone offset, then layer the “latest verdict before month-end” billing rule on top of the first two clicks.

## How this pairs with Grok_Analysis.md

Grok_Analysis.md shows the concrete SQL gaps (padding, URL-encoded IDs, incomplete slot/time maps, missing month-close window) that cost the 0.84 score; this overview explains why those gaps exist in the domain and which concepts to master next.
