# Week 6 – The Dwell: dag.sql vs gold_submit.sql

**Your score:** 0.6853 (#3 of 5, top 60%)  
**Your file:** `dag.sql`  
**Top-1 file:** `gold_submit.sql`  
**Rows built:** 43,311 of 48,948  
**Points:** +120  

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

1,104 rows matched no record (cost 2,208 points). The largest column gaps are `bill_to` (only 23 % correct), `gate_out_time` (51 %), and `visit_state` (68 %).

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Missing intermediate models / bill-to & line as-of | `bill_to` is only 23 % correct; gold isolates visit_lines for the terminal-day lookup. |
| 2 | Last-non-null / gate-out & visit state | Newest row often omits gate_out or state; gold’s visits_latest carries last-non-null. |
| 3 | Visit key & unit number normalization | Leading zeros, spaces, missing check digit split or drop visits. |
| 4 | Tariff as-of + day-level aggregation | Rate changes and restated days; gold’s visit_days + tariff_day_rates price each day once. |
| 5 | Booking ref (camelCase + truncated JSON) | Partial recovery; gold handles both key names and string fallback. |
| 6 | Incremental key & late batches | Your rk and filter are good but slightly different from gold’s src_key skip. |

---

## 1. Missing intermediate tables and bill-to lookup

### Your current code (before)

You build only four tasks and do the final join inside `storage_charges`. Line history is read, but the as-of bill-to / test-flag logic is not isolated.

### Proposed change (after)

Gold materializes:

- `visits_latest` – one row per visit with last-non-null of every attribute
- `visit_lines` – as-of bill_to and is_test using the terminal discharge day
- `visit_days` – one row per (visit, terminal day) with the correct days_chg and tariff
- `tariff_day_rates` – as-of rate for every needed day
- `visit_charges` – sum of priced days (total and in-period)

Then `storage_charges` is a simple join of the three clean tables, filtering `is_test = 0`.

### Explanation

- **Before:** bill-to recovery is incomplete; many visits get no line match or the wrong night’s agent.
- **After:** the line that was valid on the terminal day of the visit is used; test lines are excluded cleanly.

**Example input**  
A line changes agent on 2026-10-05. A container is discharged on 2026-10-04 (terminal day).

**Your behavior**  
Often joins to the latest snapshot → wrong bill_to.

**Gold behavior**  
`visit_lines` looks up the snapshot whose snap_day covers the discharge terminal day → correct old agent.

**Why it matters**  
`bill_to` is the lowest column (23 %). “A line whose agent changed”, “a line gone from the list”, and “unloaded near the 06:00 cutoff” are all scored.

**What to change**  
Extract the as-of line logic into its own task that joins on terminal discharge day.

---

## 2. Last-non-null for gate_out_time and visit_state

### Your current code (before)

In `storage_charges` you rank events and use a printf trick to take the last non-null of several columns, but the ranking key and the set of columns differ slightly from gold, and visit_state is taken from the absolute latest event even when null.

### Proposed change (after)

Gold’s `visits_latest` builds a fixed-width sort key per column:

```sql
max(CASE WHEN gate_utc IS NOT NULL THEN
     COALESCE(upd_utc,'0000-00-00T00:00:00Z') || COALESCE(batch_day,'0000-00-00') || COALESCE(loaded_utc,'0000-00-00T00:00:00Z') || gate_utc
   END) AS m_gate
```

then `substr(..., 51)`. State is normalized after the last-non-null value is obtained.

### Explanation

- **Before:** some gate_out times and states are lost when the newest row is partial.
- **After:** every column independently keeps its newest non-null value, ordered by real update time then batch then load.

**Example input**  
Night 1: gate_out_time = '2026-10-10T14:00:00Z', state = 'discharged'.  
Night 3: new row with gate_out_time = NULL, state = 'gated_out'.

**Your behavior**  
gate_out_time often becomes NULL.

**Gold behavior**  
gate_out_time stays the earlier value; state becomes 'gated_out'.

**Why it matters**  
“Newest row missing fields” is 45 % of the data. gate_out_time is only 51 % correct.

**What to change**  
Adopt the same last-non-null pattern for every attribute and normalize state vocabulary after the collapse.

---

## 3. Visit key and unit-number normalization

### Your current code (before)

```sql
CASE WHEN length(visit_gkey) = 8 AND visit_gkey NOT GLOB '*[^0-9]*' THEN visit_gkey END
```

and unit_nbr requires exactly 11 characters with a strict pattern.

### Proposed change (after)

Gold strips leading zeros / `.0`, accepts more formats, and reconstructs the check digit when the number is 10 characters.

### Explanation

- **Before:** padded keys and missing check digits create duplicate or dropped visits.
- **After:** one canonical visit_gkey and unit_nbr.

**Why it matters**  
“Visit keys with leading zeros” (only 43 % recovered) and “numbers with no check digit” (65 %).

**What to change**  
Normalize keys more aggressively before the partition.

---

## 4. Day-level charges and as-of tariff

### Your current code (before)

You resolve daily charges with a window and then price them, but the tariff lookup and the in-period filter are mixed inside the final task.

### Proposed change (after)

Gold’s `visit_days` collapses to one days/tariff per (visit, eff_day), preferring restated rows. `tariff_day_rates` does a correlated as-of lookup. `visit_charges` sums `round(days * rate_i)` with a `<= '2026-10-19'` filter for the period figure.

### Explanation

- **Before:** some restated days or mid-stay rate changes are priced at the wrong rate or counted twice.
- **After:** each terminal day is priced exactly once at the rate that was in force that day.

**Why it matters**  
“A rate change during the stay”, “the same day sent twice”, “days charged after the close”, “days waived later”.

**What to change**  
Isolate day resolution and the as-of rate so the final sum is trivial.

---

## 5. Booking reference recovery

### Your current code (before)

You try `json_extract(..., '$.booking_ref')` and a limited string search.

### Proposed change (after)

Gold also looks for `"bookingRef"` and falls back to a string parse when `json_valid` fails (truncated remarks).

### Explanation

- **Before:** camelCase keys and truncated JSON lose the ref.
- **After:** both key names and a tolerant string extraction succeed.

**Why it matters**  
“Camel-case JSON keys” (62 %) and “JSON cut short”.

**What to change**  
Add the camelCase path and the instr-based fallback.

---

## Recommended pattern (SQL / DAG)

1. Keep history tasks incremental with a stable unique key that skips already-seen source rows.
2. Materialize `visits_latest` (last-non-null), `visit_days` (per terminal day), `tariff_day_rates` (as-of), `visit_lines` (as-of bill-to / test).
3. Final `storage_charges` is only the join + integer rounding to cents + `WHERE is_test = 0`.

Start by extracting `visits_latest` and `visit_lines`. Those two changes address the largest column gaps (`bill_to`, `gate_out_time`, `visit_state`).
