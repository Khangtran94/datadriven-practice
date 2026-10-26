# Week 06 — The Dwell | Challenge Overview

> **Purpose:** Conceptual learning guide. Evaluation results and submission-specific scoring belong in `GPT_Analysis.md`, not here. Source: [README](./README.md); implementations: [dag.sql](./dag.sql), [gold_submit.sql](./gold_submit.sql). Examples below are illustrative, not hidden records.

## Business problem and output grain
The terminal invoices shipping lines for storage during visits, combining a yard change log (`unit_visit`), a slowly changing line/agent snapshot (`line_operator`), and effective-dated tariffs (`tariff_rate`). Raw extracts span 2026-09-25 through 2026-10-24; the invoice-period close is **2026-10-19**. The target `storage_charges` must contain **one row per visit_gkey**, not per container, charge date, or source event. It holds `visit_gkey`, `unit_nbr`, `visit_state`, `gate_out_time`, `booking_ref`, `storage_usd`, `storage_in_period_usd`, and `bill_to`. Exclude test lines based on relevant historical state.

## Domains / conceptual difficulty
**Difficulty: 5/5** for a timed SQL/DAG exercise: append-only events, incremental ingestion, business-calendar cutoffs, last-non-null updates, replay/restatement, effective dating, missing snapshot nights, and exact currency outputs interact. An individually correct cleaning rule may still be wrong when applied at the wrong grain or time.

Skill-equivalence estimates (heuristics, **not actual employment tenure or a hiring verdict**):

| Work evaluated | Approximate exposure required | Evidence |
|---|---|---|
| Fully understanding this challenge | ~3–6 years-equivalent of production data modeling practice | Temporal reconciliation, CDC-like state, late arrivals and billing correctness |
| User submission design | ~2–4 years-equivalent | Three incremental history tables, temporal parsing, windowed resolution, joins and billing calculations; relatively dense final query |
| Reference solution design | ~4–7 years-equivalent | Splits per-visit, per-charge-day, per-tariff-day and as-of line lookups into distinct bounded models; compact last-non-null aggregation |

These ranges compare techniques, **not** people; code length cannot establish seniority.

## Model the problem before writing SQL
| Model | Intended grain | Reason it exists |
|---|---|---|
| `unit_visit_history` | Distinct ingested event/version | Preserve replayable source events |
| `tariff_rate_history` | Tariff/effective-date/version history | Retain rate corrections |
| `line_operator_history` | Line/snapshot-day version | Preserve agent and test state |
| `visits_latest` (reference) | One row / visit | Latest **non-null per attribute**, not latest entire row |
| `visit_days` (reference) | One row / visit / charge day | Restatement replaces original; dedupe reloads |
| `tariff_day_rates` (reference) | One row / tariff / charged day | Effective-date as-of price |
| `visit_lines` (reference) | One row / visit | Agent and test status at discharge terminal day |
| `visit_charges` (reference) | One row / visit | Separate lifetime and in-period priced totals |
| `storage_charges` | One row / visit | Join resolved parts and emit invoice format |

## Important traps and illustrative tests
1. **Raw keys are not business keys.** `'0012345678'` and `'12345678 '` refer to one visit after canonicalization. Dedupe/partition **after** normalizing the key. Two visits of `ABCD1234567` are still separate visits.
2. **Container check digit.** `unit_nbr` may have separators or only ten ISO-6346 base characters; normalize first, then compute/verify digit as required. A strict length-11 filter loses recoverable numbers.
3. **Nullable state changes.** Visit event A has `gate_out_time=2026-10-05T10:00:00Z`; later event B changes state but gate time is null. The resulting visit keeps A's gate time and B's state.
4. **Alias vocabulary.** Gate app `landed/on_hold/delivered/restowed` maps to canonical `discharged/held/gated_out/transshipped`. Normalize aliases before validating.
5. **JSON edge cases.** `{"bookingRef":"BK-1234567"}` is the same semantic field as `booking_ref`; truncated JSON must never crash the entire query. Blank `"-"` or `"N/A"` refs are null.
6. **Epoch and offsets.** Example `1791162000` (seconds) and a 13-digit millisecond number need different scaling. No-offset local times use terminal UTC+08. Convert to real instants before ordering.
7. **Terminal day ≠ UTC date.** A shift day runs 06:00–06:00 local. Compute terminal day from discharge instant in UTC+08 with the 06:00 boundary; do not blindly use UTC calendar date for line lookup.
8. **As-of line party.** If carrier `ABCD` changes from agent X to Y on Oct 05, a visit discharged Oct 04 bills X, even if the latest snapshot says Y. Snapshot gaps and retired lines require preserving prior snapshots.
9. **Do not exclude ever-test lines.** A carrier test on Oct 01 but live on Oct 07 is eligible for appropriately dated visits; test flag is temporal.
10. **Late/replayed loads.** A row loaded Oct 22 may belong to an Oct 17 batch or update. Watermark solely on batch date or load text can miss it. Recompute affected visit keys rather than only appending final output.
11. **Same-day corrections.** If day Oct 10 is charged 2 days and restated to 1, the answer is 1, not 3. Deduplicate identical replays and prefer restatement.
12. **Negative days.** A waiver of `-1` is valid; filtering to positive charges overbills.
13. **Effective-dated rates.** Rate $5 before Oct 10, $7 from Oct 10: three charged days on Oct 09/10/11 cost $19 (5+7+7), not $21.
14. **Period versus lifetime.** A visit billed $19 in total but with Oct 11 after an Oct 10 close would show $12 in-period. Here use actual close **Oct 19**.
15. **Stable tie-breaking.** If update timestamps match, batch/load metadata must resolve deterministic precedence; do not rely on arbitrary row order.
16. **Join cardinality.** Rates must have one eligible version per tariff/day; line lookup one agent per visit; duplicate joins silently inflate currency.

For every case, exercise null markers (`NULL`, `\\N`, `N/A`), casing/spacing, duplicate ingestion, and same-day ties. Treat the sample as illustrative and follow the README's exact formatting/types.

## Submission versus reference: design lessons
The submission [dag.sql](./dag.sql) builds three incremental histories plus a comprehensive `storage_charges` query with CTEs including `visit_events_ranked`, `daily_charge_resolved`, `tariff_effective_windows`, `line_billing_windows` and `visit_billing_parties`. This demonstrates a real attempt at each domain rather than a naive current-snapshot join.

The reference [gold_submit.sql](./gold_submit.sql) promotes semantic intermediates into separate tasks: `visits_latest`, `visit_days`, `tariff_day_rates`, `visit_lines` and `visit_charges`. Its per-column max-with-order-key strategy is concise, though it depends on stable timestamp encoding and prefix length. The difference is **grain isolation and explicit invariants**, not simply fewer lines or inherently better window syntax. The submission's dense target query makes it harder to inspect intermediate row counts and cardinality independently.

## Learning checklist (priority)
- [ ] Define one canonical visit key and prove every raw event maps to it.
- [ ] Implement a last-non-null **per-field** test with null latest updates and equal timestamps.
- [ ] Resolve one visit/day with duplicate, negative and restated charges.
- [ ] Build an effective-date as-of price, including corrected same-effective-date rates.
- [ ] Resolve line agent/test status as of discharge terminal day with missing snapshot nights.
- [ ] Compare period close and lifetime totals for visits continuing beyond Oct 19.
- [ ] Run queries that verify `COUNT(*)=COUNT(DISTINCT visit_gkey)` in final; analogous counts at each intermediate grain.
- [ ] Build a late-arrival rerun case: previously produced visit must be replaced deterministically.
- [ ] Compare results on clean, noisy and boundary timestamps. Document tests actually run separately from proposed tests.

## General production translation
This is a compact **event-sourcing + temporal dimension + incremental reconciliation** exercise. In production, maintain immutable history, canonical identities, reasoned replay windows/affected-key recomputes, audited pricing, deterministic ties and anomaly monitors. Distinguish correctness from cost: aggressive pushdown can reduce work but can also drop late records if the watermark is not trustworthy.

**Evidence boundaries:** Task descriptions and conditions above come from README; named CTEs/tasks come from the two SQL files. Illustrative examples and experience ranges are teaching hypotheses; no new SQL execution or hidden-data validation was performed for this overview.
