# Week 5: The Close — SQL/DAG Review

**Challenge type:** SQL/DAG  
**Files reviewed:** `README.md`, `dag.sql` (submission), and `gold_submit.sql` (reference)  
**Analysis status:** Static comparison only. No SQL was executed as part of this review.

## 1. Summary

The task asks for a nightly DAG that builds **one clean row per payment** for a finance close through **2026-10-12**, using data from **2026-09-18 to 2026-10-17**. The raw tables are short-lived copies, so the solution must preserve useful history, tolerate duplicate/replayed batches, and revisit data that arrives late.

The submitted DAG creates three incremental history tasks using plain `SELECT *`, then builds `fct_payments` by selecting directly from `payments_history`. That final query does not visibly reduce the history to one row per payment, reconcile settlement movements, convert amounts to USD, or resolve merchant country. It also calls `json_extract` without validating the metadata JSON first.

The README reports **score 0.0000, rank #11 of 13, 0 of 99,261 rows built**, and says the run **crashed at task `fct_payments`**. The README explains that truncated/malformed JSON can cause JSON functions to fail. This makes the unguarded JSON extraction a concrete risk and a plausible explanation for the crash, but the exact runtime exception is not included in the available evidence, so it cannot be stated as the confirmed root cause.

The most important lesson: this is not a simple select-and-rename task. It is a history-reconstruction and financial-reconciliation problem, with DAG configuration and safe parsing as prerequisites.

## 2. Score and evaluator evidence

| Evidence in `README.md` | Reported result |
|---|---:|
| Score | 0.0000 |
| Rank | #11 of 13 |
| Rows built | 0 of 99,261 |
| Work per raw row | 0.07× median |
| Run | Crashed at task `fct_payments` |
| Statements | 4 |
| Scored | 2026-10-18 |

Every listed output column has 0% correct and 99,261 missed rows; `order_ref` has 98,665 missed rows. Because the task crashed before producing the target rows, these results do not establish that each output expression independently failed validation. Fixing the crash is necessary, but not sufficient to establish correctness.

## 3. Impact-ranked findings

| Priority | Finding and evidence | Likely impact | Recommended change |
|---|---|---|---|
| 1 — execution blocker | `fct_payments` calls `json_extract(metadata, '$.order_ref')` directly. README warns malformed/truncated JSON can make JSON functions fail. | A single malformed metadata value can abort the final task, leaving zero output rows. Exact crash cause remains unconfirmed without the exception. | Guard JSON functions with `json_valid`; safely handle malformed/truncated metadata and both key spellings. |
| 2 — output grain | The final query selects directly from `payments_history`; it does not group or rank history to one row per payment. The task explicitly says one row per payment. | Duplicate history rows can create multiple fact rows for a payment. | Normalize keys and resolve the payment's attributes to one output row per canonical payment ID. |
| 3 — incremental history is not defined | The submitted history tasks are configured as `materialized: incremental` but do not specify the reference's `incremental_strategy: merge` or `unique_key: [rk]`. They select raw rows unchanged. | Replayed batches can accumulate duplicates; incremental reruns may not be idempotent. Exact materialization defaults depend on the runner. | Define a stable row key and merge/upsert behavior, while retaining genuinely distinct history events. |
| 4 — settlement values are aliases | `settled AS settled_usd` and `settled AS settled_in_period_usd` use the same source field for both outputs. Reference SQL aggregates settlement movements across days and separately within a period. | Multi-night payouts, reversals, duplicate extracts, and period cutoffs can all make totals wrong. | Deduplicate settlement events by the task's event/batch semantics, aggregate all movements, and separately aggregate movements in the requested period. |
| 5 — amounts are not converted | `amount AS amount_usd` labels the raw amount as USD without visible currency handling or FX lookup. | Currency minor units differ; foreign currency amounts and rates can be wrong or missing. | Normalize amount units, select a valid FX rate as of the relevant payment date, then convert and round to USD. |
| 6 — missing merchant attribution | `NULL AS merchant_country` always outputs NULL. | The country output cannot be correct for payments whose merchant history provides a country. | Resolve merchant snapshots and join the country effective on the payment date. |
| 7 — latest row may not contain every attribute | The submission does not merge usable fields from history. README says newer rows can omit older fields and that an old state can arrive in a newer batch. | Choosing one entire “latest” row may lose values; choosing latest by load time alone may select an older state. | Normalize timestamps and batch/correction metadata; resolve each attribute with explicit, documented precedence. |
| 8 — inconsistent identifiers and dirty values | README describes IDs losing leading zeros or changing case, textual NULL markers, inconsistent status casing, timestamps in multiple formats, and blank order references. | Joins and grouping split one entity into multiple keys; filters silently exclude or misclassify records. | Normalize sentinels, canonical IDs, statuses, country codes, timestamps, and empty references before joining or grouping. |
| 9 — late arrivals and replayed days | README says batches can land after the run starts, an old window can be replayed, and a day can be sent twice. | A pipeline that processes only the current batch can miss late records or double-count restated data. | Make ingestion/history idempotent and ensure downstream payment results are recomputed for affected keys when late/corrected records arrive. |
| 10 — reference period discrepancy | The reference's `st` CTE filters `sd.eff_day BETWEEN '2026-02-02' AND '2026-02-26'`, while README describes the task window in September–October 2026. | Copying that literal would likely calculate the wrong in-period settlement amount. | Resolve the intended close period from the task contract; do not copy the reference's February dates without verification. |

## 4. Finding 1: guard malformed JSON before extraction

### Code before — current submission

From `weekly/week-05-the-close/dag.sql`, task `fct_payments`:

```sql
SELECT payment_id,
       status,
       amount AS amount_usd,
       settled AS settled_usd,
       settled AS settled_in_period_usd,
       captured_at,
       json_extract(metadata, '$.order_ref') AS order_ref,
       NULL AS merchant_country
FROM payments_history;
```

### Why it can fail

The README explicitly lists JSON cut off at the landing column width as a data condition and warns that JSON functions can fail on malformed JSON. If `metadata` contains an incomplete JSON document, calling `json_extract` directly may raise an error rather than return NULL. A task-level failure prevents the output table from being built.

This is a **plausible immediate cause**, not a confirmed diagnosis: the available README reports the failing task but does not show the exact exception.

### Code after — safer extraction pattern

The following is a focused SQLite-style example, consistent with functions used in the reference SQL. Confirm the runner's exact dialect before adopting it.

```sql
CASE
  WHEN json_valid(metadata) THEN
    COALESCE(
      json_extract(metadata, '$.order_ref'),
      json_extract(metadata, '$.orderRef')
    )
  ELSE NULL
END AS order_ref
```

This guards the JSON calls and checks both snake_case and camelCase keys. It does not recover a value from truncated JSON; it deliberately returns NULL for malformed content. If recovering a reference from damaged text is required, that should be a separate, carefully tested fallback rather than an assumption that malformed JSON can be parsed safely.

Also normalize empty or placeholder references after extraction. The README says some blank references contain values such as a dash or `N/A`; those should not automatically be treated as genuine order references.

**Worked scenario:** if one row has valid metadata `{"orderRef":"A-17"}`, the fallback can return `A-17`. If another row has truncated metadata such as `{"order_ref":"A-18"`, `json_valid` is false and the expression returns NULL rather than invoking extraction on invalid JSON.

## 5. Finding 2: history tasks need stable row identity and idempotent merges

### Code before — current DAG configuration

```yaml
payments_history:
  materialized: incremental
  depends_on: [raw_payments]
fx_rates_history:
  materialized: incremental
  depends_on: [raw_fx_rates]
merchants_history:
  materialized: incremental
  depends_on: [raw_merchants]
```

The corresponding submitted SQL is effectively:

```sql
-- task: payments_history
SELECT *
FROM raw_payments;

-- task: fx_rates_history
SELECT * FROM raw_fx_rates;

-- task: merchants_history
SELECT * FROM raw_merchants;
```

### Code after — reference configuration pattern

The reference config uses explicit merge semantics and a row key:

```yaml
payments_history:
  materialized: incremental
  incremental_strategy: merge
  unique_key: [rk]
  depends_on: [raw_payments]
fx_history:
  materialized: incremental
  incremental_strategy: merge
  unique_key: [rk]
  depends_on: [raw_fx_rates]
merchants_history:
  materialized: incremental
  incremental_strategy: merge
  unique_key: [rk]
  depends_on: [raw_merchants]
```

The reference derives `rk` from source values and load/correction metadata. This is a reference pattern, not proof that its exact concatenation is the only valid key. A production design should prefer a documented event ID when available, or a collision-safe canonical key built from the fields that define a distinct source record.

**Important distinction:** two identical rows copied because a batch was retried may represent one source event, while two settlement movements on different nights can both be legitimate. Deduplicating by payment ID alone would destroy valid history. Define the grain of each history table first, then choose a key that distinguishes real events but makes replaying the same event idempotent.

**Worked scenario:** if the same batch is loaded twice, a merge on a stable row key should not double the event. If a payment has two genuine settlement movements on separate nights, those movements need different event identities and both must remain available for aggregation.

## 6. Finding 3: build one row per payment from the history

The submitted fact query has no `GROUP BY`, ranking, or other explicit reduction step. It reads every row in `payments_history`, even though the task contract calls for one clean row per payment.

### Code before — current behavior

```sql
SELECT payment_id, status, amount AS amount_usd,
       settled AS settled_usd,
       settled AS settled_in_period_usd,
       captured_at,
       json_extract(metadata, '$.order_ref') AS order_ref,
       NULL AS merchant_country
FROM payments_history;
```

### Code after — structural pattern, not a drop-in replacement

The reference uses multiple CTEs to normalize source rows, establish a comparable ordering key, and then aggregate attributes by canonical payment ID. The following shows the intended shape only; it must be connected to the actual normalized column names and tie-breaking rules in the DAG.

```sql
WITH normalized_payment_history AS (
  -- Normalize IDs, sentinels, statuses and timestamps here.
  -- Retain a stable source-row key and explicit event/batch metadata.
  SELECT ...
  FROM payments_history
),
payment_attributes AS (
  -- Resolve each output attribute using its own non-NULL rule and
  -- a deterministic precedence for effective date, source update,
  -- load time, and correction metadata.
  SELECT ...
  FROM normalized_payment_history
  WHERE canonical_payment_id IS NOT NULL
  GROUP BY canonical_payment_id
)
SELECT ...
FROM payment_attributes;
```

This is intentionally a template rather than executable SQL: the ellipses represent transformations that must be filled from the actual runner schema and task contract. Do not paste it as a complete query.

Why resolve attributes separately? The README says the newest row can lack fields present on an older row. Taking the newest row wholesale can therefore lose a previously known amount, merchant ID, or order reference. But blindly taking the newest non-NULL value is also unsafe if an older state is replayed under a newer batch. The ordering rule must use business/event chronology and correction metadata—not load time alone—and must define deterministic tie-breaking.

The reference uses a grouping CTE (`g`) and a composite ordering key based on effective day, load time, and update time. Review that approach against the task's edge cases before reusing it; equal timestamps and manual corrections with unchanged timestamps need an explicit tie-breaker.

## 7. Finding 4: distinguish all-time settlement from settlement in the close period

### Current submission

```sql
settled AS settled_usd,
settled AS settled_in_period_usd
```

These aliases produce the same value twice. They do not aggregate separate nightly movements and do not apply a period filter.

### Reference approach

The reference SQL creates settlement-related CTEs named `sd` and `st`. It resolves movements by payment and effective day, then calculates both an all-period settlement total and a separately filtered in-period total. This matches the business distinction in the README: the amount paid out over several nights is the sum of those movements, and reversals can be negative.

### Recommended design

1. Determine what one settlement row represents and identify replay/correction semantics.
2. Normalize its effective day and amount representation.
3. Deduplicate repeated copies of the same movement without discarding distinct movements.
4. Aggregate all valid movements for `settled_usd`.
5. Aggregate only movements whose effective day belongs to the requested close period for `settled_in_period_usd`.
6. Confirm how refunds, reversals, and negative movements affect each total.

**Period warning:** the reference currently contains `BETWEEN '2026-02-02' AND '2026-02-26'` for `st_in`. This does not match the September–October 2026 task window described in the README. Treat it as a discrepancy to resolve, not as a date range to copy automatically. Use the authoritative task contract and test both inclusive boundaries.

## 8. Finding 5: currency conversion needs units and an as-of FX rate

### Current submission

```sql
amount AS amount_usd
```

This renames `amount` without a visible conversion. The README specifically describes zero-decimal and three-decimal currencies, rows represented in major rather than minor units, and FX rates that may be duplicated, corrected, or arrive late.

### Reference approach

The reference:
- classifies currencies into minor-unit divisors;
- normalizes rate records and chooses one rate per currency/day;
- checks rate direction against a currency's typical rate distribution;
- carries rates across effective date ranges using `lead(rate_day)`;
- uses the rate applicable to the payment's creation day; and
- converts the amount to USD and rounds the result.

These are substantial business rules. They should be verified against the challenge contract rather than copied without understanding.

### Recommended logic

Conceptually, conversion is:

```text
amount in major currency units
    = raw amount / currency minor-unit divisor
amount_usd
    = amount in major currency units × valid USD FX rate
```

The raw amount may already be in major units, so the pipeline needs a reliable way to distinguish that legacy representation from minor units. A decimal-point heuristic can help explain the reference implementation but should not be assumed to be universally correct for production data. Establish the unit convention per source/version when possible.

For FX, select the most recent valid rate on or before the payment's applicable date, after resolving duplicate rates and rate direction. A same-day equality join is insufficient when weekends have no rate. Late-arriving rate corrections must cause affected outputs to be recomputed.

## 9. Finding 6: merchant country must be effective on the payment date

The submission hardcodes `NULL AS merchant_country`. The reference normalizes merchant IDs and countries, resolves one merchant snapshot per batch day, and uses effective date ranges to associate the merchant's country with the payment's creation date.

This matters because the README says a merchant can move and the landing retains only recent copies. Using only the latest country would rewrite history: a payment made before the move would incorrectly receive the new country.

Recommended approach:
- canonicalize merchant IDs (including leading zeros and case rules) consistently on both sides of the join;
- normalize country values and reject invalid country-code shapes;
- resolve duplicate snapshots for the same merchant/day deterministically;
- join on the payment's effective date within the merchant's effective interval;
- test new merchants, moved merchants, missing snapshots, and merchants absent from later copies.

The reference has separate country and test-status timelines (`mc` and `mt`). That is a useful reminder that fields can change independently and should not always share one “latest merchant row” rule.

## 10. Normalize identifiers, statuses, timestamps, and missing values before joins

The README enumerates these conditions:
- NULL-like strings such as `N/A`, `none`, and `-`;
- payment and merchant IDs with inconsistent case or lost leading zeros;
- status values with inconsistent casing/padding and a second gateway's vocabulary;
- timestamps represented as UTC strings, local offsets, epoch seconds, epoch milliseconds, or different ISO forms;
- camelCase `orderRef` alongside `order_ref`;
- blank references that contain placeholder text;
- corrections and old rows that arrive under a newer batch date.

These are not cosmetic issues. If a raw ID is used as a grouping key before canonicalization, one payment may be split into several apparent payments. If timestamps are compared as arbitrary strings, lexical order may not equal chronological order. If textual NULL markers are not normalized, missing values can pass filters and joins as if they were genuine data.

Create a clear normalization stage before grouping:
- convert known null sentinels to SQL NULL;
- canonicalize identifiers with a rule that preserves meaningful leading zeros;
- map gateway-specific statuses to a common vocabulary, keeping unknown states observable rather than silently mapping everything;
- parse supported timestamp formats into a common UTC representation, including epoch units and offsets;
- normalize order references and country codes;
- retain source fields needed to audit ambiguous conversions.

Do not assume every numeric-looking ID should be cast to a number. IDs are identifiers, not measurements.

## 11. DAG behavior: dependencies, materialization, and failed upstream tasks

Both DAGs place `fct_payments` after the three history tasks. The reference additionally uses `trigger_rule: all_done` for the fact task. This changes execution behavior when an upstream task fails; it is not automatically correct or incorrect without the runner's contract.

Do not add `all_done` simply because the reference does. First establish what the runner exposes to downstream tasks after an upstream failure and whether building a fact table from incomplete history is acceptable. For a finance close, silently publishing partial results can be worse than failing clearly. If the runner supports it, combine an explicit policy with data-quality checks that prevent an incomplete close from being mistaken for a complete one.

The README's reported failure point is `fct_payments`, but the exact exception is absent. The visible unguarded JSON extraction is a plausible query-level failure; the evidence does not rule out another expression or runner issue.

## 12. Validation checklist

**Not executed in this review.** Run these checks in the actual challenge environment before treating a proposed change as correct.

- [ ] The DAG parses and every task's dependencies point to existing task names.
- [ ] The final task completes with malformed/truncated metadata present.
- [ ] The final output has exactly one row per canonical payment ID.
- [ ] No duplicate history event is introduced by rerunning the same batch.
- [ ] Distinct settlement movements across nights are all retained; repeated copies are counted once.
- [ ] Negative settlement movements/reversals reduce totals as intended.
- [ ] `settled_usd` reconciles to all valid movements and `settled_in_period_usd` reconciles only to the authoritative close window.
- [ ] Period start and end boundaries are tested, including the discrepancy between the README dates and the reference's February literals.
- [ ] Amounts for zero-decimal, two-decimal, and three-decimal currencies reconcile to known examples.
- [ ] Major-unit and minor-unit source representations are handled according to an explicit rule.
- [ ] A weekend payment can use the latest eligible prior FX rate; duplicate and late FX corrections are resolved deterministically.
- [ ] A merchant move changes country attribution only for payments in the appropriate effective period.
- [ ] A newer partial row does not erase older valid attributes; a replayed older state does not override a genuine newer state.
- [ ] Late-arriving batches and manually restated days cause affected payment outputs to be recomputed.
- [ ] Status normalization covers both gateway vocabularies and leaves unexpected values diagnosable.
- [ ] Null/placeholder order references are returned as NULL, while both supported JSON key spellings are tested.
- [ ] Output row counts and monetary totals are reconciled against task-provided expectations, where available.

## 13. Facts versus hypotheses

**Directly evidenced by the repository**
- The README reports score 0, rank #11/13, zero of 99,261 rows built, and a crash at `fct_payments`.
- The submitted fact task invokes `json_extract` without a validity guard, selects history rows directly, aliases raw `amount` as USD, aliases `settled` to both settlement outputs, and hardcodes merchant country to NULL.
- The reference has merge/unique-key configuration and substantially more normalization, history resolution, settlement aggregation, FX conversion, and merchant effective-date logic.
- The reference's settlement-period literal is in February 2026, whereas the README describes a September–October 2026 task window.

**Not confirmed by the available evidence**
- That malformed JSON was the exact exception causing the observed crash.
- That the runner's default incremental strategy necessarily duplicated rows in this run.
- That every implementation detail in `gold_submit.sql` is mandatory for a nonzero score.
- That any proposed code will pass the evaluator; no tests were run here.

## 14. Reusable lessons

1. **Start from the output grain.** “One row per payment” is a data-model requirement, not just a final SELECT.
2. **Treat incremental as a correctness contract.** Define row identity, replay behavior, corrections, and late-arrival handling explicitly.
3. **Separate history from facts.** Preserve distinct events in durable history, then derive one row per entity and aggregate movements according to their business meaning.
4. **Normalize before joining.** Dirty keys and inconsistent time formats cause silent data loss as well as wrong values.
5. **Make unsafe parsing safe.** Guard JSON operations when the landing data can be truncated, and treat extraction failure separately from fallback recovery.
6. **Financial labels must reflect calculations.** A column called `amount_usd` must be converted to USD; a period total must actually apply the period.
7. **Use the reference critically.** It is a valuable implementation example, but date literals and other assumptions still need to agree with the written contract.
8. **Separate crash diagnosis from data-quality diagnosis.** Fixing a task crash may allow output to be produced, but the result still needs grain, duplicate, and monetary reconciliation tests.

**Recommended high-level flow:** raw copies → normalized, idempotent histories → resolved payment attributes and event movements → settlement reconciliation and FX conversion → effective-date merchant attribution → validated one-row-per-payment fact table.
