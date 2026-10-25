# Week 6 – The Dwell: Challenge Overview

**One-sentence verdict:** Medium-hard container-terminal storage billing (target ~2–4 YoE) that forces incremental history, last-non-null collapse, as-of tariff and line lookups, and multi-night charge aggregation on dirty change-log feeds.

## Domain & context

You are a data engineer at a port container terminal. Shipping lines are billed for every day a container sits in the yard. The raw nightly copies keep only a few nights of data: `unit_visit` is a change log (every visit that changed or was charged that night), `line_operator` is a nightly snapshot of shipping lines (including bill-to agent and test flag), and `tariff_rate` arrives in full on the first night and then only as deltas. The goal is one clean billing row per visit for the period ending 2026-10-19, covering the loads from 2026-09-25 to 2026-10-24. Because the landing zone forgets old nights, the DAG must retain history across runs.

## Core data-engineering problems

- Multi-night change log: the same visit appears on every night it changed or was charged; the desired state is the last non-null of each column, not the newest row whole.
- Incremental retention: landing keeps only a few nights, so history tables must merge and skip already-seen source rows.
- Late and restated data: nights that land after the morning run, re-sent terminal days, and old extracts under new batch IDs.
- Terminal-day cutoff: the business day cuts at 06:00 local; discharge and charge days must be computed in terminal time, not raw UTC.
- As-of tariff: a rate can change mid-stay; each charged day must use the rate effective on or before that day, and a later publication for the same effective day replaces the earlier one.
- As-of line / bill-to / test flag: lines change agents, go live from test, or disappear; the party billed is the one valid on the terminal day of discharge (or the relevant charge day).
- Dirty strings: null-as-text, leading zeros or spaces on visit keys, spaced/cased box numbers, gate-app vocabulary (`landed`, `on_hold`, …), camelCase JSON keys, truncated JSON, epoch timestamps, offsets, missing check digits.
- Signed days and waivers: days_chg can be negative; the total and the in-period figure must both respect them.
- Duplicate and restated nights: exact duplicate rows inside a batch and the same terminal day sent twice must not double-count.

## Concepts you must master

| Concept | Why it appears |
|---------|----------------|
| Incremental merge + unique key | Landing forgets after a few nights; late batches and restatements must upsert. |
| Last-non-null per column | Newest row often omits fields that an older row of the same visit still holds. |
| As-of / SCD-style lookup | Tariff rate and line bill-to/test flag change over time; the value on the terminal day matters. |
| Terminal-day arithmetic | 06:00 cutoff and local vs UTC offsets move the billed day. |
| Tolerant JSON + string fallback | Booking ref arrives under `booking_ref` or `bookingRef` and the remarks column can be truncated. |
| Windowed last-non-null / ranking key | Avoid multiple sorts; carry values behind a fixed-width sort key and take max. |
| Integer money math | Rates and charges are accumulated in minor units then rounded half-away-from-zero to cents. |
| Dedup before aggregation | Same day sent twice or duplicate rows in a batch would overstate days. |

## Difficulty & experience estimate

| Aspect | Level | Estimated YoE | Short rationale |
|--------|-------|---------------|-----------------|
| Problem statement (README) | Intermediate–Advanced | 2–4 | Many intentional dirty conditions, multi-night history, as-of joins, and terminal-day rules. |
| Your submission (`dag.sql`) | Intermediate | 1–3 | Solid cleaning and ranking in the final task, but fewer intermediate models and some recovery gaps (bill-to, gate-out, visit state). |
| Reference solution (`gold_submit.sql`) | Advanced | 3–5 | Explicit intermediate tables (visits_latest, visit_days, tariff_day_rates, visit_lines), careful src_key, last-non-null, and integer rounding. |

## Skill map

- **Primary:** incremental merge, last-non-null collapse, as-of joins, terminal-day calculation, tolerant parsing of timestamps/JSON/keys.
- **Secondary:** integer money arithmetic, vocabulary normalization, check-digit reconstruction, test-line filtering.
- **Can defer:** full SCD2 history beyond the needed as-of snapshot, advanced JSON schema validation.

## Learning path

1. Add the missing intermediate tables (visits_latest, visit_days, tariff_day_rates, visit_lines) so each concern is isolated and testable.
2. Strengthen the visit_gkey normalization (strip leading zeros/spaces, handle `.0`) and the booking_ref extraction (both camelCase keys + string fallback for truncated JSON).
3. Verify the as-of line lookup uses the terminal discharge day and that negative days and restated days are aggregated exactly once.

## How this pairs with Grok_Analysis.md

The Overview explains the business problem, the intentional hard conditions, and the concepts you need. Grok_Analysis.md then shows the concrete code differences between your `dag.sql` and the gold solution, ordered by score impact, with before/after snippets and example inputs.
