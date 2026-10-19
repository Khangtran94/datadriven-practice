# Week 5 – The Close: dag.sql vs gold_submit.sql

**Your score:** 0.0000 (#11 of 13, top 85%)  
**Your file:** `dag.sql`  
**Top-1 file:** `gold_submit.sql`  
**Run:** crashed at task `fct_payments`  
**Rows built:** 0 of 99,261

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

**Why the score is 0**  
The DAG crashed inside `fct_payments`. Your history tasks are raw `SELECT *` (no cleaning, no key, no merge strategy). The final task then does a naive projection and a bare `json_extract` on dirty metadata. Any of the conditions listed in the README (NULL-as-text, truncated JSON, epoch times, duplicate keys, missing rates, etc.) can raise or produce an empty/invalid result set, so the task fails and nothing is scored.

The gold solution treats every raw table as a dirty log that must be cleaned, keyed, and incrementally merged before the fact table can safely join and aggregate.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Crash in `fct_payments` / no real transform | Run never produced rows → score 0. |
| 2 | History tasks are `SELECT *` | No cleaning, no unique key, no merge → duplicates, nulls-as-text, and late batches poison everything downstream. |
| 3 | DAG config (incremental + unique_key + trigger) | Without `merge` + `unique_key` and `trigger_rule: all_done`, late/corrected batches are not handled correctly. |
| 4 | Payment key + last-state logic | Finance wants 1 clean row per payment; you never collapse the history. |
| 5 | Amount / settled / currency decimals + FX | 0- and 3-decimal currencies, major-vs-minor units, missing Saturday rates, inverted rates. |
| 6 | Merchant country + test flag + order_ref | SCD-style lookup by payment day; JSON recovery for camelCase / truncated metadata. |
| 7 | Settled-in-period window | Money that moved after the close window must be excluded from `settled_in_period_usd`. |

---

## 1. Crash in `fct_payments` (the score-zero cause)

### Your current code (before)

```sql
-- task: fct_payments
SELECT payment_id,
       status,
       amount AS amount_usd,
       settled AS settled_usd,
       settled AS settled_in_period_usd,
       captured_at,
       json_extract(metadata, '$.order_ref') AS order_ref,
       NULL AS merchant_country
FROM payments_history;   -- 1 row per key: a second row for the same key costs 2
```

### Proposed change (after)

Build a cleaned `payments_history` first (see §2), then in `fct_payments`:

- Keep only valid payment ids (`pay_????????`)
- Collapse to **one row per payment** with last-non-null logic ordered by effective day + loaded_at + updated_at
- Convert amount/settled using the correct minor-unit divisor and the FX rate that was valid on the payment’s created day
- Look up merchant country / is_test as-of the payment day
- Recover `order_ref` with a tolerant JSON path (and a fallback string parse when JSON is truncated)
- Filter out test merchants
- Format `captured_at` as ISO with `Z`

Gold ends with something in this shape:

```sql
SELECT pid AS payment_id,
  status,
  round(amount_raw + CASE WHEN amount_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS amount_usd,
  round(settled_raw + ..., 2) AS settled_usd,
  round(in_raw + ..., 2) AS settled_in_period_usd,
  replace(...captured..., ' ', 'T') || 'Z' AS captured_at,
  order_ref,
  country AS merchant_country
FROM v
WHERE is_test = 0;
```

### Explanation

- **Before**: raw columns are projected straight through. `json_extract` on truncated or non-JSON metadata raises; duplicate payment_ids produce multiple rows (or the engine aborts). Result = crash, 0 rows.
- **After**: every dirty condition is normalized upstream; the fact table only sees clean typed columns and therefore never raises.

**Example input**  
`metadata` = `{"orderRef":"ABC"` (truncated, camelCase, missing closing brace).

**Your behavior**  
`json_extract` fails or returns NULL → task can crash; even if it survives you still have no merchant_country and un-normalized amounts.

**Gold behavior**  
Tolerant parse recovers `order_ref`; amounts and FX are computed; merchant is looked up; one clean row is emitted.

**Why it matters**  
Crash = score 0. Everything else is unreachable until this task succeeds.

**What to change**  
Never project raw text columns into the fact table. Clean in the three history tasks, then aggregate safely in `fct_payments`.

---

## 2. History tasks are bare `SELECT *`

### Your current code (before)

```sql
-- task: payments_history
SELECT *
FROM raw_payments

-- task: fx_rates_history
SELECT * FROM raw_fx_rates;

-- task: merchants_history
SELECT * FROM raw_merchants;
```

### Proposed change (after)

Each history task must:

1. Normalize null-as-text (`'null'`, `'N/A'`, `'-'`, … → real NULL)
2. Trim whitespace / control characters
3. Parse timestamps that arrive as epoch, local offset, `T`/`Z`/`UTC`/`GMT` spellings
4. Emit a stable `rk` (row key) used by the incremental merge
5. Derive `batch_day` / `eff_day` from `_batch_id` or `_correction_for`
6. Normalize ids (payment_id lower, merchant_id → `M######`)
7. Normalize status vocabulary (`authorised` → `authorized`, etc.)

Gold’s `payments_history` starts like this (abbreviated):

```sql
WITH c AS (
  SELECT
    quote(payment_id)||'|'||quote(_batch_id)||'|'||... AS rk,
    CASE WHEN lower(trim(payment_id, ...)) IN ('','null','n/a',...) THEN NULL
         ELSE trim(payment_id, ...) END AS payment_id,
    -- same pattern for every text column
    ...
  FROM raw_payments
),
t AS ( /* strip UTC/GMT/T, prepare JSON */ ),
p AS ( /* parse epoch / offset timestamps into datetime */ ),
d AS ( /* batch_day + corr_day from _batch_id / _correction_for */ )
SELECT rk, lower(payment_id) AS pid, ... normalized columns ...,
       coalesce(corr_day, batch_day, date(loaded_ts, '-1 day')) AS eff_day
FROM d;
```

Do the analogous cleaning for `fx_history` and `merchants_history`.

### Explanation

- **Before**: every dirty value lands in the history tables. Downstream joins and aggregates see text nulls, mixed-case statuses, unparsed epochs, and duplicate physical rows.
- **After**: history tables contain typed, deduplicable rows that the fact table can trust.

**Example input**  
`updated_at = '1700000000'` (epoch seconds) and `status = 'Authorised '`.

**Your behavior**  
Stored as raw text → ordering and status matching break.

**Gold behavior**  
Parsed to a real datetime; status normalized to `authorized`.

**Why it matters**  
58 % of payments appear on more than one night; 35 % of batches contain exact duplicate rows; many timestamps are not ISO. Without cleaning, “last row wins” is meaningless.

**What to change**  
Replace every `SELECT *` with a cleaning CTE pipeline that ends in a stable `rk` + typed columns.

---

## 3. DAG config (incremental merge + trigger)

### Your current code (before)

```yaml
# inside the /* dag.yml */ comment
tasks:
  payments_history:
    materialized: incremental
    depends_on: [raw_payments]
  fx_rates_history:
    materialized: incremental
    depends_on: [raw_fx_rates]
  merchants_history:
    materialized: incremental
    depends_on: [raw_merchants]
  fct_payments:
    materialized: table
    depends_on: [payments_history, fx_rates_history, merchants_history]
```

### Proposed change (after)

```yaml
tasks:
  payments_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_payments]
  fx_history:                    # note the shorter name gold uses
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_fx_rates]
  merchants_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_merchants]
  fct_payments:
    materialized: table
    trigger_rule: all_done
    depends_on: [payments_history, fx_history, merchants_history]
```

### Explanation

- **Before**: plain incremental without a unique key just appends. Late corrections and re-sent days create duplicates. `fct_payments` may start before a history task has finished a late batch.
- **After**: `merge` on `rk` upserts; `trigger_rule: all_done` lets the fact table run even if an upstream task is skipped/empty for a given night.

**Why it matters**  
“A day sent twice over”, “old rows in a newer batch”, and “a state that came days late” are all real conditions. Without merge + all_done the fact table either double-counts or never sees the correction.

**What to change**  
Add `incremental_strategy: merge`, `unique_key: [rk]`, and `trigger_rule: all_done` exactly as gold does.

---

## 4. One clean row per payment (last-state + fill)

### Your current code (before)

You never collapse history. The fact query simply reads every row from `payments_history`.

### Proposed change (after)

Gold builds a ranking key and then takes the last non-null of each attribute:

```sql
WITH p AS (
  SELECT *,
    coalesce(eff_day, '0000-00-00')
      || coalesce(loaded_ts, '0000-00-00 00:00:00')
      || coalesce(updated_ts, '0000-00-00 00:00:00') AS k
  FROM payments_history
  WHERE pid GLOB 'pay_????????'
),
g AS (
  SELECT pid,
    nullif(substr(max(k || coalesce(status_n, '')), 49), '') AS status,
    substr(max(CASE WHEN amt IS NOT NULL THEN k || amt END), 49) AS amt,
    -- same pattern for currency, created_ts, mid, order_ref, captured_ts
  FROM p
  GROUP BY pid
)
```

Settled amounts are summed **per effective day** (because payouts can span nights) and later converted with the FX rate of the payment’s created day.

### Explanation

- **Before**: multiple physical rows per payment → either crash, double-counting, or “second row for the same key costs 2”.
- **After**: one logical row that carries the newest status, the best non-null amount/currency/merchant/order_ref, and the correct captured_at.

**Example input**  
Night 1: payment authorized, amount present, merchant_id present.  
Night 3: same payment captured, amount NULL on the new row, merchant_id NULL.

**Your behavior**  
Two rows or a final row that lost the amount/merchant.

**Gold behavior**  
One row: status = captured, amount and merchant filled from the older row, captured_at from the newer row.

**Why it matters**  
“Last row lacks older fields” is 45 % of the data. Taking the newest row whole throws the older fields away.

**What to change**  
Rank by (eff_day, loaded_ts, updated_ts) and take last-non-null per column; never `SELECT *` into the fact table.

---

## 5. Currency decimals, major/minor units, and FX

### Your current code (before)

```sql
amount AS amount_usd,          -- no divisor, no rate
settled AS settled_usd
```

### Proposed change (after)

```sql
CASE WHEN cur IN ('BIF','CLP',...,'XPF') THEN 1.0          -- zero-decimal
     WHEN cur IN ('BHD','IQD',...,'TND') THEN 1000.0       -- three-decimal
     ELSE 100.0 END AS dv,

-- later
CASE WHEN instr(amt, '.') > 0 THEN CAST(amt AS REAL)       -- already major units
     ELSE CAST(amt AS REAL) / dv END * rate AS amount_raw
```

FX side:

- Keep only the latest rate per (currency, rate_day)
- Reject outlier rates (compare to median; also accept the reciprocal if it matches)
- Forward-fill so a Saturday payment can use Friday’s rate
- USD = 1.0

### Explanation

- **Before**: every amount is treated as already-USD major units. JPY/KWD and the many other 0-/3-decimal currencies are wrong by 100× or 10×; missing rates produce NULL or crash.
- **After**: correct minor-unit scaling + as-of FX rate → amount_usd / settled_usd match the gold numbers.

**Why it matters**  
“0 and 3 decimal currencies”, “more 0 and 3 place money”, “major units not minor”, “created on a day with no rate”, “2 rates for 1 day”, “a rate that came after the run” are all scored conditions.

**What to change**  
Implement the divisor table, the median-guarded FX series, and the as-of join on `date(created_ts)`.

---

## 6. Merchant country, test flag, order_ref

### Your current code (before)

```sql
json_extract(metadata, '$.order_ref') AS order_ref,
NULL AS merchant_country
```

### Proposed change (after)

- Normalize merchant_id to `M######`
- Build an as-of country (and is_test) series with `lead(batch_day)` so each payment day sees the country that was true that day
- Fall back to the single known country when a merchant never moved
- Drop rows where `is_test = 1`
- Recover `order_ref` both via `json_extract` on valid JSON and via a string search when the JSON was truncated (`"order_ref"` / camelCase)

### Explanation

- **Before**: merchant_country is always NULL; test merchants are not filtered; many order_refs are lost to casing or truncation.
- **After**: country is correct for the payment day, test traffic is removed, and order_ref recovery is robust.

**Why it matters**  
“A seller that moved”, “a seller that went live”, “a seller gone from the copy”, “camel case key in the JSON”, “JSON cut at the field width” are all present in the feed.

**What to change**  
SCD-style merchant lookup + tolerant order_ref extraction + `WHERE is_test = 0`.

---

## 7. Settled-in-period window

Gold sums settled amounts **per effective day**, then keeps only the portion whose `eff_day` falls inside the close window (in the gold file the window used for `st_in` is the period being closed). Money that moved after the close date is excluded from `settled_in_period_usd` while still appearing in the lifetime `settled_usd`.

Your code simply aliases `settled` to both columns, so any post-period movement is counted in the period figure.

---

## Recommended pattern (SQL / DAG)

1. **dag.yml** – `incremental` + `merge` + `unique_key: [rk]` on every history task; `trigger_rule: all_done` on the fact table.
2. **Each history task** – clean null-as-text → parse timestamps → normalize ids/status/currency → emit `rk` + typed columns + `batch_day`/`eff_day`.
3. **fct_payments** – filter valid ids → last-non-null collapse per payment → as-of FX and merchant joins → correct minor-unit math → filter test merchants → emit the eight required columns.

Start by making the three history tasks produce clean, mergeable rows. Only then rewrite `fct_payments`. Once the crash is gone you will see real row counts and can iterate on the remaining recovery gaps listed in the README.
