# Week 06 — The Dwell | GPT Analysis

**Submission:** [dag.sql](./dag.sql) · **Reference:** [gold_submit.sql](./gold_submit.sql) · **Type:** SQLite-style SQL with templated incremental DAG · **Contract:** [README](./README.md).

## Evaluator evidence
README reports **score 0.6853**, **rank #3/5**, **43,311 / 48,948** output rows, **1,104 unmatched rows** (2,208 points), and 1.4× median work per raw row. Reported field correct rates: `bill_to` 23%, `gate_out_time` 51%, `visit_state` 68%, `booking_ref` 80%, `unit_nbr` 86%, `storage_usd` and `storage_in_period_usd` each 86%, `visit_gkey` 88%. These are *observed evaluator numbers*, not explanations of root causes.

**Important correction to simplistic comparisons:** The submitted SQL **already implements** independent last-non-null logic for several fields, per-day charge resolution, tariff as-of windows, line snapshot forward-fill and as-of party selection. The reference's use of separate materialized tasks is not by itself proof that these methods are missing from the submission or why a field scored poorly.

## Impact-ranked findings
| Priority | Evidence / exact code anchor | Likely consequence | Recommendation |
|---|---|---|---|
| 1 | `unit_visit_history.fields_normalized`: `length(visit_gkey) = 8` | Padded visit IDs nullified, split or dropped across history/joins; README says padded keys handled poorly | Canonicalize before validating and partitioning |
| 2 | `unit_visit_history.fields_normalized`: strict `length(unit_nbr)=11` | Rejects recoverable missing-check-digit numbers | Strip separators, compute ISO 6346 check digit for valid 10-char bases |
| 3 | `fields_normalized.visit_state_n` + `storage_charges.visit_attributes` | Gate vendor aliases omitted; latest event's null state forces output null | Expand documented synonyms and take latest **non-null canonical** state |
| 4 | `dates_prepared.booking_json` / `booking_tail` | Searches snake_case only, not camelCase | Accept `bookingRef`; robust fallback for truncated JSON |
| 5 | `daily_charge_versions` and history incremental filter | Restated/replayed days and late batches risk incorrect winner or missing rows | Model restatement precedence and verified arrival watermark; test reruns |
| 6 | `line_billing_windows`, `visit_billing_parties` | As-of logic exists; historical line agent/test and terminal cutoffs still warrant targeted tests; `bill_to` evaluator correctness is low | Audit keys, dates and snapshot completeness before replacing the algorithm |

Relative impact is inferred from README prevalence/field results, not proven field-level attribution.

## Finding 1 — Visit identity before history and ranking
**Code before (actual):**
```sql
CASE
    WHEN length(visit_gkey) = 8
     AND visit_gkey NOT GLOB '*[^0-9]*'
    THEN visit_gkey
END AS visit_gkey_n
```
A value `'0012345678'` (10 digits) becomes NULL while `'12345678'` survives. Because future joins and partitions use `visit_gkey`, events for the same real visit may fail to reunite.

**Code after (proposed replacement expression for `visit_gkey_n`, SQLite dialect):**
```sql
CASE
  WHEN trim(visit_gkey) NOT GLOB '*[^0-9]*'
   AND trim(visit_gkey) <> ''
   AND length(ltrim(trim(visit_gkey), '0')) BETWEEN 1 AND 8
  THEN printf('%08d', CAST(ltrim(trim(visit_gkey), '0') AS INTEGER))
  WHEN trim(visit_gkey) NOT GLOB '*[^0-9]*'
   AND trim(visit_gkey) <> ''
   AND length(ltrim(trim(visit_gkey), '0')) = 0
  THEN '00000000'
END AS visit_gkey_n
```
This is a **candidate** if the contractual canonical identity is 8-digit zero-padded text; confirm actual business convention and whether leading zeros are significant before adopting. Keep `visit_gkey_n` in all downstream grains. If this value is numerical identity rather than padded-text identity, choose its explicit canonical representation consistently instead.

## Finding 2 — ISO 6346 number reconstruction
**Code before (actual):**
```sql
CASE
    WHEN length(unit_nbr) = 11
     AND substr(unit_nbr, 1, 4) NOT GLOB '*[^A-Z]*'
     AND substr(unit_nbr, 5, 7) NOT GLOB '*[^0-9]*'
    THEN unit_nbr
END AS unit_nbr_n
```
It normalizes separators first but rejects a valid 10-character owner/category+serial base. A reference solution can derive the check digit. **After:** create a dedicated `unit_base` transformation and a deterministic ISO-6346 checksum calculation: letter weights prescribed by ISO 6346, weighted sum by powers of two across ten characters, `mod 11`, with remainder 10 mapped to 0. Validate against published examples. Do **not** simply append 0 or accept any 11-digit tail. This needs a tested helper/lookup CTE; the code above must not be replaced by an incomplete expression.

## Finding 3 — Latest state versus latest non-null
**Code before (actual):**
```sql
ROW_NUMBER() OVER (
  PARTITION BY visit_gkey
  ORDER BY upd_ts DESC, batch_day DESC, loaded_ts DESC, rk DESC
) AS event_rank
```
```sql
MAX(CASE WHEN event_rank = 1 THEN visit_state_n END) AS visit_state
```
In the **same** `visit_attributes` CTE, the submission already retains last non-null values for `gate_ts`, `unit_nbr_n`, `line_scac_n`, and `booking_ref`, using an inverted rank prefix. The state is the exception.

**Code after (replace only the `visit_state` expression):**
```sql
substr(MAX(CASE WHEN visit_state_n IS NOT NULL
  THEN printf('%09d',999999999-event_rank) || visit_state_n
END), 10) AS visit_state
```
This follows your *existing* prefix technique; does not require replacing six other fields or adding six window sorts. Example: older `discharged`, latest unknown/null state → prior known `discharged` survives. Ensure the 9-digit rank assumption is valid at your scale; alternatively use an explicit ordered window/aggregate.

Additionally extend `fields_normalized`'s CASE:
```sql
WHEN visit_state = 'landed' THEN 'discharged'
WHEN visit_state = 'delivered' THEN 'gated_out'
WHEN visit_state = 'restowed' THEN 'transshipped'
```
`on_hold` is already handled. Validate aliases from README, not invented categories.

## Finding 4 — Camel-case booking reference
**Code before (actual):**
```sql
CASE WHEN json_valid(remarks)
THEN json_extract(
  CASE WHEN json_valid(remarks) THEN remarks END,
  '$.booking_ref'
) END AS booking_json
```
```sql
WHEN instr(remarks, '"booking_ref"') > 0
```
**Code after (replace `booking_json` expression and extend the fallback search):**
```sql
CASE WHEN json_valid(remarks) THEN
  COALESCE(
    json_extract(remarks, '$.booking_ref'),
    json_extract(remarks, '$.bookingRef')
  )
END AS booking_json
```
For invalid/truncated JSON, support both literal key spellings in the existing `booking_tail` extraction and validate the captured value as `BK-` plus exactly seven digits. Do not call `json_extract` on invalid JSON, and treat `'-'`/`'N/A'`/empty as null.

## Finding 5 — Business day, replay and amount invariants
**Actual submission excerpts:**
```sql
ROW_NUMBER() OVER (
  PARTITION BY e.visit_gkey, e.charge_terminal_day
  ORDER BY e.batch_day DESC, e.loaded_ts DESC, e.rk DESC
) AS charge_rank
```
```sql
LEFT JOIN tariff_effective_windows AS t
  ON t.tariff_cd_n = COALESCE(d.tariff_cd_n, v.tariff_cd)
 AND d.charge_terminal_day >= t.effective_day
 AND (d.charge_terminal_day < t.next_effective_day OR t.next_effective_day IS NULL)
```
These are substantive strengths: a single winning charge-day version, and rate effective windows. However, README explicitly says a **restated day replaces** the original, and an old state can be loaded in a newer batch. The code selects by batch/load order; confirm that this is equivalent to restatement priority when both a replay and a restatement are present. If not, add a normalized `is_restated` priority **before** update/load metadata, while preserving the original charge-day grain.

**Illustrative ledger:** Oct 10 first reported `days=2`; later explicitly restated to `days=1`; yet another load replays the original `days=2`. Expected day total is 1, not 2 or 3. With a tariff rate of $7/day, the resolved charge is $7. Negative `days=-1` must remain a valid waiver.

The submission computes money in cents and rounds daily; reference uses ten-thousandths before final cents rounding. Their numerical behavior may differ on half-cent boundaries; derive the exact required rounding semantics from README and compare targeted decimal cases before changing arithmetic.

## Finding 6 — As-of line lookup: diagnose, don't assume absent
The submission implements:
- `line_snapshot_versions`: one line/snapshot-day row.
- `line_value_groups` and `line_billing_values`: independent forward-fill.
- `line_billing_windows`: temporal validity intervals.
- `visit_billing_parties`: as-of join on `discharge_terminal_day`.

**Code before (actual):**
```sql
LEFT JOIN line_billing_windows AS l
    ON l.line_scac_n = v.line_scac
   AND v.discharge_terminal_day >= l.valid_from
   AND (v.discharge_terminal_day < l.next_batch_day
        OR l.next_batch_day IS NULL)
```
This is **already** an as-of interval join. The reference instead materializes `visit_lines` separately, uses discharge's 06:00 terminal-day conversion and the last snapshot on/before the day (or earliest fallback). A failed `bill_to` can arise upstream from invalid visit IDs, line codes, date normalization, discarded history, snapshot gaps or a boundary mismatch—not solely from the final join.

**After (diagnostic before rewrite):**
```sql
-- Run against materialized models if available; adjust names to your runner.
SELECT COUNT(*) AS visits,
       SUM(CASE WHEN line_scac IS NULL THEN 1 ELSE 0 END) AS no_line_code,
       SUM(CASE WHEN discharge_terminal_day IS NULL THEN 1 ELSE 0 END) AS no_day
FROM visit_attributes;
```
For a test visit discharged at 05:59 local and one at 06:01 local, verify distinct intended terminal days and that exactly one valid line interval joins. The reference's `visit_lines` is a useful independently inspectable alternative, not a proven obligatory method.

## DAG and incremental architecture
Submission declares `unit_visit_history`, `tariff_rate_history`, `line_operator_history` incremental MERGE by `rk`; `storage_charges` is rebuilt as a table. It uses a raw-event `json_array(...)` key and source filters by parsed/partially textual ingestion dates. Confirm that reruns of old business days loaded late remain reachable and a retry does not double-count the same source event. Historical raw rows with different load metadata must be distinguished from logical daily charge restatements. The reference has additional intermediate tasks; these reduce ambiguity and make grain-level tests simpler, but increase materialization/storage work.

## Validation checklist — *proposed, not executed*
- [ ] `SELECT visit_gkey, COUNT(*) FROM storage_charges GROUP BY 1 HAVING COUNT(*)>1` returns no rows.
- [ ] Canonicalized visit keys unify padded and unpadded events without merging distinct visits.
- [ ] Last event NULL state does not erase the last known canonical state.
- [ ] Vendor synonyms (`landed`, `on_hold`, `delivered`, `restowed`) map correctly.
- [ ] 10-character ISO-6346 base recovers a verified check digit.
- [ ] `bookingRef` and `booking_ref` both resolve; truncated JSON does not fail execution.
- [ ] Test 06:00 local boundary at 05:59 and 06:01.
- [ ] A restated charge day replaces older charge events even after a replay.
- [ ] Tariff change and same-effective-day correction yield exactly one valid rate/day.
- [ ] Negative waiver and after-close days affect lifetime/in-period totals separately.
- [ ] Non-test line after formerly test state is not excluded incorrectly.
- [ ] A late old batch updates existing visit results after rerun.
- [ ] Compare cents/ten-thousandths rounding on boundary decimal amounts.

**Tests actually executed for this report:** none. This document is a static code and README comparison; no hidden records, benchmark, execution plan or sample equivalence are claimed.

## Reusable principles
Normalize **before** defining identity; rank by **business event time** with deterministic ties; use latest **non-null per field**; separate event, visit, day and tariff grains; treat effective-dated dimensions with as-of logic; prefer verifiable intermediate invariants to blindly shortening SQL; and distinguish score evidence from hypothesized causes.
