# Week 8 – The Auction: Challenge Overview

## 1. One-sentence verdict
This is a hard production-style incremental + as-of billing challenge for a data engineer with roughly 3–5 years of experience in ad-tech / search-auction data platforms.

## 2. Domain & context
- **Simulated business**: a search engine that sells a few ad slots on every results page via real-time auction; advertisers pay only for clicks.
- **Pipeline goal**: produce one clean row per ad shown (impression) for the window 2026-10-09 → 2026-11-07 (billing month closed 2026-10-31), with served_at / served_date (account timezone), slot, clicked flag, and billed_micros.
- **Raw inputs**: two nightly copy tables (`ad_events` and `accounts`). `ad_events` is a multi-writer log (serve / click / fraud-verdict rows). `accounts` is a nightly snapshot of open advertiser accounts (timezone, currency). Both feeds arrive late, are re-copied, contain null-as-text, malformed IDs, and multiple vocabularies.

## 3. Core data-engineering problems
The README deliberately injects the following production realities (ordered roughly by frequency/impact):

1. **Impression-id normalisation** – base64 padding (`=`), base64url (`-` `_`), and percent-encoding (`%2B` `%2F`) must be stripped/decoded so click rows join their serve.
2. **Multi-format timestamps** – microseconds, milliseconds, seconds, ISO, California offsets, and other writer-specific forms must be reduced to a single epoch so first-click / last-verdict ranking works.
3. **Event vocabulary & click settlement** – impression/CLICK/IVT/reinstated must map to serve/click/invalid/valid; an impression row must absorb its (up to two) clicks and the latest pre-close verdict.
4. **Legacy slot names** – ML2, mainline-2, B1, above-1, etc. must become top-N / bottom-N.
5. **Price units** – micros (850000), decimal dollars (0.85), yen integers, and comma formats must all become billed_micros.
6. **As-of account timezone** – accounts open/close mid-month, move east once, and experience DST; the zone in force on the serve day decides served_date.
7. **Late files & re-exports** – Asia files and re-copied days arrive after the run; a watermark on loaded_epoch (or sensor) is required.
8. **Billing rules** – at most two clicks per impression, last verdict before the account’s month close, invalid = 0, duplicate-click price 0, etc.

The scoring harness penalises both missing rows and incorrect served_date / billed_micros / slot values.

## 4. Concepts you must master

| Concept | Why it appears in this week |
|---------|-----------------------------|
| Incremental history + stable event/account key | Re-copied files and late Asia rows must be merged, not dropped. |
| Tolerant ID normalisation | Base64 padding, URL encoding, dashes, leading zeros. |
| Multi-format epoch parsing | Writer-specific times must sort correctly for first-click / last-verdict. |
| As-of join to account versions | Timezone (and DST) in force on the serve day. |
| Click aggregation + verdict ranking | Up to 2 clicks; latest pre-close valid/invalid decides billed_micros. |
| Slot & event vocabulary maps | Legacy names and free-text event words. |
| Price → micros conversion | Decimals, commas, yen, already-micros. |
| Month-close credit logic | Verdicts after the account’s calendar month close do not affect the invoice. |

## 5. Difficulty & experience estimate

| Lens | Level | Estimated YoE | Short rationale |
|------|-------|---------------|-----------------|
| Problem statement (README) | Hard | 3–5 years | Dozens of realistic ad-server / fraud-filter / billing dirty-data and late-data conditions; requires incremental design, as-of timezone logic, multi-format parsing and precise click/verdict ranking. |
| Your submission (`dag.sql`) | Mid | ~2–3 years | Solid null cleaning, basic incremental + as-of account intervals, partial event/slot maps and LPAD, but incomplete ID/time/price normalisation and simplified billing. |
| Reference solution (`gold_submit.sql`) | Senior+ | 5+ years | Full production defensive style: comprehensive epoch parser, base64/URL ID cleaning, full vocabulary & slot maps, price-to-micros, as-of TZ with DST offsets, loaded_epoch watermark, and precise up-to-2-clicks + last-pre-close-verdict billing. |

## 6. Skill map

**Primary skills trained**
- Designing incremental history tables with a content-stable unique key that survives re-exports
- Normalising multi-format timestamps and impression IDs so joins and ranking work
- As-of joins against versioned account timezones (including DST)
- Click aggregation and fraud-verdict ranking with month-close rules

**Secondary skills**
- Legacy slot-name and free-text event vocabulary maps
- Price unit conversion (micros / decimal / integer)
- Late-file watermark or sensor

**Can be deferred on a first pass**
- Perfect recovery of every exotic scientific-notation or offset spelling
- Micro-optimisations of the ranking key

## 7. Learning path
1. Strengthen the history tasks: stable unique key, proper merge (not append-only), and full null-as-text + ID normalisation (padding, URL encoding, dashes, leading zeros).
2. Replace the limited epoch parser with a multi-format one and expand the slot / event maps; then re-score served_at, served_date and slot.
3. Isolate the click-aggregation + last-pre-close-verdict logic and the as-of timezone (with DST offsets); then re-score billed_micros and clicked.

## 8. How this pairs with Grok_Analysis.md
- **Grok_Challenge_Overview.md** (this file) = understand the business problem, the intentional data-engineering difficulties, the concepts involved, and the experience bar.
- **Grok_Analysis.md** = understand exactly what your current `dag.sql` does wrong, the concrete before/after SQL, and how to verify each fix.

Read the Overview first to know *what* the week is testing; use the Analysis to fix *your* code.
