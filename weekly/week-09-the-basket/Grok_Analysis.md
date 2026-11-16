# Week 09 – The Basket: dag.sql vs gold_submit.sql

**Score:** 0.6682 (rank #2 of 5)  
**Rows:** 17,036 of 17,036  

| Impact | Issue | Columns hit | Why it costs points |
|--------|-------|-------------|---------------------|
| 1 | Subtotal calculation misses weight-by-pound, 2-for-$5 offers, store labels, UPC leading-zero, and as-of price | `subtotal` (38%) | Most of the 10,612 wrong rows |
| 2 | Item count does not treat weight items as quantity 1 or handle negative scans / replacements correctly | `items` (78%) | 3,696 wrong |
| 3 | Tip parsing does not strip `$` / `USD` and does not always take the latest by event time | `tip` (87%) | 2,153 wrong |
| 4 | Delivered_at sometimes null when status is delivered (late sync or cancelled-then-reinstated edge) | `delivered_at` (94%) | 950 missed |

## 1. Subtotal and item-count logic (biggest gap)

**Your current code (before)** — `order_charges` lines task (excerpt):

```sql
lines AS (
SELECT s.order_id,
     CASE
       WHEN substr(s.code, 1, 1) = '2' AND length(s.code) >= 11 THEN COALESCE(s.qty, 1)
       WHEN pr.sold_by = 'lb' THEN 1
       ELSE COALESCE(s.qty, 1)
     END AS items,
     CASE
       WHEN substr(s.code, 1, 1) = '2' AND length(s.code) >= 11
         THEN COALESCE(s.qty, 1) * CAST(substr(s.code, 7, 5) AS INTEGER)
       WHEN pr.sold_by = 'lb'
         THEN CAST(ROUND(COALESCE(s.weight_lb, s.qty, 0) * pr.price * 100 + 0.0000001) AS INTEGER)
       WHEN pr.price IS NOT NULL
         THEN COALESCE(s.qty, 1) * CAST(ROUND(pr.price * 100) AS INTEGER)
       ELSE 0
     END AS cents
FROM scans_history s
JOIN orders o ON o.order_id = s.order_id AND o.status = 'delivered'
LEFT JOIN declined d ON d.scan_id = s.scan_id
LEFT JOIN pr ON pr.code = s.code
          AND o.placed_at >  pr.vfrom
          AND (pr.vto IS NULL OR o.placed_at <= pr.vto)
WHERE d.scan_id IS NULL)
```

**Proposed change (after)** — align with gold’s weight, label, and as-of handling:

```sql
-- after cleaning code to 12-digit / store-label form and collapsing price history to change points
line AS (
  SELECT oid, q, w,
    CASE WHEN length(code12) = 12 AND code12 LIKE '2%' THEN 'label' ELSE sb END AS sb,
    CASE WHEN length(code12) = 12 AND code12 LIKE '2%' THEN (substring(code12 from 7 for 5))::integer ELSE pc END AS pc
  FROM items WHERE prn = 1
),
agg AS (
  SELECT oid,
    sum(CASE WHEN sb = 'lb' THEN CASE WHEN coalesce(w, q) < 0 THEN -1 WHEN coalesce(w, q) > 0 THEN 1 ELSE 0 END ELSE coalesce(q, 0) END) AS n,
    sum(CASE WHEN sb = 'lb' THEN (round(coalesce(w, q) * pc + 0.000001))::integer
             ELSE (round(coalesce(q, 0) * pc + 0.000001))::integer END) AS cents
  FROM line GROUP BY oid
)
```

**Explanation**  
Weight items must contribute 1 to the item count regardless of pounds, and the line total is `round(weight * price_per_lb)`. Store labels (barcode starting with 2) embed the price in cents and are not on the price list. Leading-zero UPCs (EAN-13 form) must be stripped before the join. Prices must be the version current at `placed_at` (as-of), not the latest. 2-for-$5 tags must be parsed to $2.50 each. Negative quantity scans subtract.  

**Example input**  
Scan: code `0123456789012` (EAN), qty `1.5`, weight_lb `NULL`, sold_by `lb`, price `1.99` current at order time.  

**Your behavior**  
No match on code → cents = 0, items = 1.5.  

**Gold behavior**  
Strips leading 0 → joins → items = 1, cents = round(1.5 * 199).  

**Why it matters**  
91 % of rows involve weight items; 70 % have leading-zero UPCs.  

**What to change**  
Normalize codes to 12 digits, keep full price history and pick the latest `lts <= placed_at`, treat `sold_by = 'lb'` as quantity 1, handle store labels by extracting the embedded price.

## 2. Tip cleaning and latest-event selection

**Your current code (before)**  
Tip is taken from `detail_tip` after a simple numeric cast; ranking is by `event_time` then `written_at`.

**Proposed change (after)**  
Strip non-numeric characters before cast and rank strictly by event timestamp:

```sql
round(coalesce((regexp_replace(o.tip_txt, '[^0-9.\-]', '', 'g'))::float8, 0), 2)
```

**Explanation**  
Tips arrive as `$5.00`, `5.00 USD`, etc. The last tip by the customer’s event time (not written time) is the one that counts.

## 3. Delivered_at nulls

**Your current code (before)**  
`CASE WHEN o.status = 'cancelled' THEN NULL ELSE o.delivered_at END`

**Proposed change (after)**  
Also null when no delivered event exists:

```sql
CASE WHEN o.last_cr = 'cancelled' OR o.delivered_ts IS NULL THEN NULL
     ELSE to_char(o.delivered_ts, 'YYYY-MM-DD"T"HH24:MI:SS"Z"') END
```

**Explanation**  
A few orders are marked delivered in status but lack a delivered event (late sync or reinstatement edge). Gold nulls the timestamp in those cases.

## Recommended pattern

- Keep full history of events, scans, and prices (do not collapse early).  
- Normalize identifiers and timestamps once in the history tasks.  
- In `order_charges` use as-of joins for prices, strip UPC leading zeros, treat weight as qty 1, extract store-label prices, and clean tip text.  
- Rank replacement decisions and tip changes by event time, not write time.
