# Week 9: The Basket: `dag.sql` vs `gold_submit.sql`

**Result [measured]:** score 0.6682, rank #2 of 5, +150 points. Rows built 17,036 of 17,036, so every order was built and the loss is all in the values. 7 statements.

Columns [measured]: `subtotal` 38% correct (10,612 wrong), `items` 78% (3,696 wrong), `tip` 87% (2,153 wrong), `delivered_at` 94% (950 missed), `status` 100% (20 wrong), `order_id` 100%.

Evidence tags: `[measured]` from the README, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data, `[untested]` code that was not run.

**How this analysis was made.** It comes from reading the README, `dag.sql` and `gold_submit.sql` line by line. **No synthetic run was made for this week**, so no number below is `[estimate]` and every "After" snippet is `[untested]`. Test each one on a small table before you trust it. The README's "Recovered" percentages are per condition, but a table often carries several conditions at once, so one bug can hide behind another.

## Impact ranking

The README lists conditions in order of cost. The areas below follow that order, restricted to the ones the code does not handle.

| # | Area | README condition (share of tables, recovered) [measured] | Hits |
|---|---|---|---|
| 1 | Scan codes and price-list codes are never made the same shape (13-digit UPC with a leading 0) | UPCs with a 0 in front (70.0%, 77%) | `subtotal`, `items` |
| 2 | The first copy of a resent day wins, so a scan the store took out stays charged | A scan the store took out (2.8%, 64%) | `subtotal`, `items` |
| 3 | Price tags `2/5.00` and `2 for 5.00` are dropped | A 2 for $5 offer (24.8%, 76%) | `subtotal` |
| 4 | Weight `20.32 oz` is rejected and the line falls back to quantity 1 | A scale that reads in ounces (15.9%, 76%) | `subtotal` |
| 5 | A scan of `-1` is thrown away instead of being subtracted | A unit taken back out (11.5%, 63%) | `items`, `subtotal` |
| 6 | Order numbers typed as `#12345678` match nothing | Order numbers typed with # (9.0%, 65%) | `items`, `subtotal`, all events |
| 7 | Tips written `$5.00` or `5.00 USD` become NULL, then 0 | Tips with $ or USD (15.0%, 71%) | `tip` |
| 8 | Event words missing from the vocabulary: `dropoff_complete`, `sub_rejected` | Each app's own words (18.0%, 75%) | `delivered_at`, `items`, `subtotal` |
| 9 | Timestamp offsets in other shapes | Times in 2 other forms (26.0%, 82%) | `delivered_at`, tips |

The order inside the table is `[inferred]`. The README gives the cost of each condition, not the cost of each line of code.

## 1. Codes: a 13-digit UPC never meets the price list

- **Your code** (`dag.sql` 153): `code,` is passed through `normalize_scan` unchanged, and the price code is only trimmed (361-364). The join at 518 is `LEFT JOIN pr ON pr.code = s.code`.
- **Gold code** (`gold_submit.sql` 119, 127-128, 132): keeps digits only, turns a 13-digit code that starts with 0 into the 12-digit form (`code12`), and joins on `ltrim(code, '0')`.
- **Example input:** the older app reports every UPC as an EAN-13: price list `036000291452`, scan `0036000291452`.
- **Your behavior:** no match, so `pr.price` and `pr.sold_by` are NULL. The line costs 0 (line 513), and a pound item counts `qty` instead of 1 (line 504). A deli label scanned in the 13-digit form starts with 0, so the test at 502 and 507 (`substr(s.code, 1, 1) = '2'`) fails too.
- **Gold behavior:** the code is 12 digits before any test, so the price and the deli label are both found.
- **Why it matters [measured]:** 70.0% of tables, recovered 77%. `subtotal` is 62% wrong, the biggest column loss.
- **Before** (`dag.sql` 153 and 518):

```sql
    code,
...
LEFT JOIN pr ON pr.code = s.code
```

- **After** `[untested]`: clean the code once in `normalize_scan` (`parsed`, replacing line 153) and the same way in `normalize_price` (`parsed`, replacing line 388).

```sql
    CASE
        WHEN code IS NULL THEN NULL
        WHEN length(regexp_replace(code, '[^0-9]', '')) = 13
             AND substr(regexp_replace(code, '[^0-9]', ''), 1, 1) = '0'
        THEN substr(regexp_replace(code, '[^0-9]', ''), 2)
        ELSE regexp_replace(code, '[^0-9]', '')
    END AS code,
```

- **How it works:** every barcode becomes digits only, and a 13-digit code that starts with 0 loses that 0, so a UPC from either app has one spelling. Then the exact-text join at 518 works, and the deli test (`starts with 2`) sees the right first digit. Nothing else changes.

## 2. A resent day: your DAG keeps the first copy, the gold keeps the last

- **Your code:** line 64-67 and 86-87 say "days already stored are never re-read: the first-sent version of a day wins". Line 197 computes `MIN(loaded_at_utc)` per batch, line 198 keeps one row per `scan_id` (`ORDER BY loaded_at_utc`), and line 205 keeps only the rows stamped with the first load.
- **Gold code** (`gold_submit.sql` 105-115): keeps every distinct row, then keeps the rows whose load stamp is the **latest** of their batch day (`lts = max(lts) OVER (PARTITION BY bday)`).
- **Example input:** day 2026-10-20 is loaded on the 21st with 400 scans. The store finds a mistake and sends the whole day again on the 22nd, 398 scans, because 2 were never charged at the register.
- **Your behavior:** the 22nd file is ignored, so the 2 scans the store took out are still charged, and `items` and `subtotal` are too high.
- **Gold behavior:** the 22nd file replaces the 21st, so the 2 scans disappear.
- **Why it matters [measured]:** README says "A scan the store took out" is 2.8% of tables, recovered 64%, the lowest recovery of the scan conditions. The README also says a pipeline that merges the second file into the first by scan keeps those scans, and one that replaces the day does not.
- **A second bug [inferred]:** line 87 compares the raw `_batch_id` (for example `20261020`) with the stored `batch_id` (`2026-10-20`). They never match, so that filter never filters anything. Line 66 is the one that works, because it compares two normalized values.
- **Before** (`dag.sql` 195-205):

```sql
dedup AS (
SELECT parsed.*,
       MIN(loaded_at_utc) OVER (PARTITION BY batch_id) AS first_load,
       ROW_NUMBER() OVER (PARTITION BY scan_id ORDER BY loaded_at_utc) AS rn
FROM parsed
WHERE scan_id IS NOT NULL)

SELECT scan_id, order_id, code, qty, weight_lb, batch_id, loaded_at_utc
FROM dedup
WHERE rn = 1
  AND COALESCE(loaded_at_utc, '') = COALESCE(first_load, '')
```

- **After** `[untested]`: store every version, and choose the latest version of each day when you read.

In `normalize_scan`, replace lines 195-205 with:

```sql
dedup AS (
SELECT parsed.*,
       ROW_NUMBER() OVER (PARTITION BY scan_id, loaded_at_utc ORDER BY loaded_at_utc) AS rn
FROM parsed
WHERE scan_id IS NOT NULL)

SELECT scan_id, order_id, code, qty, weight_lb, batch_id, loaded_at_utc
FROM dedup
WHERE rn = 1
```

In the header, change both `unique_key: ['scan_id']` of `normalize_scan` and `scans_history` to `['scan_id', 'loaded_at_utc']`. Delete the `{% if is_incremental() %} ... {% endif %}` blocks at lines 64-67 and 85-88, so a resent day is read again. In `order_charges`, add this CTE and use it in `lines` instead of `scans_history`:

```sql
scans_latest AS (
SELECT * FROM (
  SELECT s.*, MAX(loaded_at_utc) OVER (PARTITION BY batch_id) AS last_load
  FROM scans_history s)
WHERE loaded_at_utc = last_load),
```

- **How it works:** the history now remembers each copy of each scan (a scan has 1 row per load). When `order_charges` runs it picks, for every day, only the rows of the newest copy. A scan the store took out is in the first copy and not in the second, so it disappears. A scan sent twice in the same file has the same stamp and still collapses into one row. The old `rn` partitioned by `scan_id` alone would have thrown the second copy away, so the partition has to include the stamp.
- **Proof:** `[untested]`.

## 3. Price tags: `2/5.00` and `2 for 5.00`

- **Your code** (`dag.sql` 400-404): only `^[0-9]+([.][0-9]+)?$` is a price, anything else is NULL, and line 433 drops rows whose price is NULL.
- **Gold code** (`gold_submit.sql` 133): `regexp_replace(price, '[^0-9.\-]', '')` turns `2/5.00` into `25.00`, which is the trap the README names ("digits taken out of it read 25.00") `[inferred]`. The gold does not seem to divide either.
- **Example input:** price list says `2/5.00` or `2 for 5.00`, which is 2.50 each.
- **Your behavior:** the row is dropped, so the item has no price and costs 0. Worse, the price history has a hole, so the interval logic at 482-497 can stretch the previous price over it.
- **Why it matters [measured]:** 24.8% of tables, recovered 76%.
- **Before** (`dag.sql` 400-404):

```sql
        CASE
            WHEN regexp_like(price, '^[0-9]+([.][0-9]+)?$')
            THEN CAST(price AS DECIMAL(18, 6))
            ELSE NULL
        END AS price,
```

- **After** `[untested]`:

```sql
        CASE
            WHEN regexp_like(price, '^[0-9]+([.][0-9]+)?$')
            THEN CAST(price AS DECIMAL(18, 6))
            WHEN regexp_like(lower(price), '^[0-9]+ ?(/|for) ?[0-9]+([.][0-9]+)?$')
            THEN CAST(regexp_replace(lower(price), '^[0-9]+ ?(/|for) ?([0-9]+([.][0-9]+)?)$', '\\2') AS DECIMAL(18, 6))
                 / CAST(regexp_replace(lower(price), '^([0-9]+) ?(/|for) ?[0-9.]+$', '\\1') AS DECIMAL(18, 6))
            ELSE NULL
        END AS price,
```

- **How it works:** a tag like `2/5.00` is read as "2 items for 5.00", and the price per item is 5.00 divided by 2. Plain prices take the first branch exactly as before.
- **Not in the gold [inferred]:** fixing this goes beyond the gold. Test it on a few rows before trusting it, since I could not check how the platform's scorer treats this case.

## 4. Weight in ounces

- **Your code** (`dag.sql` 161-165): `weight_lb` must match `^[0-9]+([.][0-9]+)?$`, so `20.32 oz` becomes NULL. Line 510 then uses `COALESCE(s.weight_lb, s.qty, 0)`, and `qty` is 1 for the newer app.
- **Gold code** (`gold_submit.sql` 121): strips everything that is not a digit, so `20.32 oz` becomes `20.32` and is read as pounds. The gold seems to miss the ounces too `[inferred]`.
- **Example input:** `weight_lb = '20.32 oz'` for an item at 4.00 per pound. The right line is 20.32 / 16 x 4.00 = 5.08.
- **Your behavior:** the weight is lost, so the line is `1 x 4.00` = 4.00. The gold would give 81.28.
- **Why it matters [measured]:** 15.9% of tables, recovered 76%.
- **Before** (`dag.sql` 161-165):

```sql
    CASE
        WHEN regexp_like(weight_lb, '^[0-9]+([.][0-9]+)?$')
        THEN CAST(weight_lb AS DECIMAL(18, 6))
        ELSE NULL
    END AS weight_lb,
```

- **After** `[untested]`:

```sql
    CASE
        WHEN regexp_like(weight_lb, '^[0-9]+([.][0-9]+)?$')
        THEN CAST(weight_lb AS DECIMAL(18, 6))
        WHEN regexp_like(lower(weight_lb), '^[0-9]+([.][0-9]+)? ?lbs?$')
        THEN CAST(regexp_replace(lower(weight_lb), '[^0-9.]', '') AS DECIMAL(18, 6))
        WHEN regexp_like(lower(weight_lb), '^[0-9]+([.][0-9]+)? ?oz$')
        THEN CAST(regexp_replace(lower(weight_lb), '[^0-9.]', '') AS DECIMAL(18, 6)) / 16
        ELSE NULL
    END AS weight_lb,
```

- **How it works:** the unit decides the factor. Pounds stay as they are and ounces are divided by 16, so every weight reaches line 510 in pounds.

## 5. A unit taken back out (`-1`)

- **Your code** (`dag.sql` 155-159): `qty` must match `^[0-9]+([.][0-9]+)?$`, so `-1` becomes NULL, and `COALESCE(s.qty, 1)` at 502, 504 and 512 turns it into **+1**.
- **Gold code** (`gold_submit.sql` 120, 163): keeps the minus sign and sums quantities. For a pound item it adds the sign of the weight (-1, 0 or +1).
- **Example input:** a shopper scans 3 units, then 1 scan of `-1`. The right quantity is 2.
- **Your behavior:** 3 + 1 = 4 units charged, and `items` and `subtotal` are both too high.
- **Why it matters [measured]:** 11.5% of tables, recovered 63%, the lowest recovery in the README outside cancellations.
- **Before** (`dag.sql` 156 and 503):

```sql
        WHEN regexp_like(qty, '^[0-9]+([.][0-9]+)?$')
...
       WHEN pr.sold_by = 'lb' THEN 1
```

- **After** `[untested]`:

```sql
        WHEN regexp_like(qty, '^-?[0-9]+([.][0-9]+)?$')
...
       WHEN pr.sold_by = 'lb' THEN CASE WHEN COALESCE(s.weight_lb, s.qty, 0) < 0 THEN -1
                                        WHEN COALESCE(s.weight_lb, s.qty, 0) > 0 THEN 1 ELSE 0 END
```

- **How it works:** the sign survives parsing, so the sum of an item's scans is its real quantity. A pound item counts as 1 when the scan is positive and as -1 when it is a take-back. Apply the same `^-?` change to the `weight_lb` regex at 162 (and in the After of section 4).

## 6. Order numbers typed with `#`

- **Your code** (`dag.sql` 147-151 for scans, 282-286 for events): `order_id` must match `^[0-9]{1,8}$`, so `#12345678` becomes NULL. A NULL order id never joins to an order.
- **Gold code** (`gold_submit.sql` 118): strips every non-digit before padding to 8.
- **Example input:** a crumpled order card, typed in as `#00012345`.
- **Your behavior:** the scan has no order, so it is dropped from the basket and `items` and `subtotal` are too low.
- **Why it matters [measured]:** 9.0% of tables, recovered 65%.
- **Before** (`dag.sql` 148-150):

```sql
        WHEN regexp_like(order_id, '^[0-9]{1,8}$')
        THEN substr('00000000' || order_id, length('00000000' || order_id) - 7, 8)
        ELSE NULL
```

- **After** `[untested]` (same change at 283-285 for events):

```sql
        WHEN regexp_like(regexp_replace(order_id, '[#]', ''), '^[0-9]{1,8}$')
        THEN substr('00000000' || regexp_replace(order_id, '[#]', ''),
                    length('00000000' || regexp_replace(order_id, '[#]', '')) - 7, 8)
        ELSE NULL
```

- **How it works:** the `#` is removed first, and the rest follows the rule you already had.

## 7. Tips with `$` or `USD`

- **Your code** (`dag.sql` 308-312): `detail` must match `^[0-9]+([.][0-9]{1,2})?$`, so `$5.00` and `5.00 usd` give a NULL tip. Line 533 then prints 0.
- **Gold code** (`gold_submit.sql` 175): `regexp_replace(o.tip_txt, '[^0-9.\-]', '')` keeps only the number.
- **Why it matters [measured]:** 15.0% of tables, recovered 71%. `tip` is 13% wrong (2,153).
- **Before** (`dag.sql` 309-310):

```sql
        WHEN canonical_event IN ('placed', 'tip_changed') AND regexp_like(detail, '^[0-9]+([.][0-9]{1,2})?$')
        THEN CAST(detail AS DECIMAL(10, 2))
```

- **After** `[untested]` (`detail` is already lower-cased at line 237):

```sql
        WHEN canonical_event IN ('placed', 'tip_changed')
             AND regexp_like(detail, '^[$]? ?[0-9]+([.][0-9]{1,2})?( ?usd)?$')
        THEN CAST(regexp_replace(detail, '[^0-9.]', '') AS DECIMAL(10, 2))
```

- **How it works:** the symbol and the currency word are accepted around a normal amount, then removed before the cast. Anything else still gives NULL.

## 8. Event words your list does not know

- **Your code** (`dag.sql` 254-255 and 264-267): the delivered list has `dropped_off` but not `dropoff_complete`, and the declined list has `substitution_rejected` but not `sub_rejected`. Unknown words pass through unchanged (line 268).
- **Gold code** (`gold_submit.sql` 44, 67-75): compares letters only, with `LIKE '%dropoff%'` for delivered, `'%reject%'` with `'%replac%'` or `'%substitut%'` for declined.
- **Example input:** README says the driver app reports `DELIVERED` or `dropoff_complete`, the customer app `tip_updated` or `sub_rejected`.
- **Your behavior:** a `dropoff_complete` order has no delivered event, so `delivered_at` is NULL. This matches `delivered_at` missed 950 [measured], and your 94% for that column `[inferred]`. A `sub_rejected` replacement is never declined, so its scan is charged.
- **Gold behavior:** `dropoff_complete` becomes `dropoffcomplete` and is delivered. `sub_rejected` becomes `subrejected`, which contains neither `replac` nor `substitut`, so the gold probably misses it too `[inferred]`.
- **Why it matters [measured]:** README "Each app's own words" is 18.0% of tables, recovered 75%.
- **Before** (`dag.sql` 254 and 264):

```sql
        WHEN event_name IN ('delivered', 'order_delivered', 'order delivered', 'order-delivered', 'delivery_completed', 'delivery completed', 'dropped_off', 'dropped off')
...
        WHEN event_name IN ('replacement_declined', 'replacement declined', 'substitution_declined', 'substitution declined', 'replacement_rejected', 'substitution_rejected')
```

- **After** `[untested]`: add the missing words to each list.

```sql
        WHEN event_name IN (..., 'dropped_off', 'dropped off', 'dropoff_complete', 'dropoff complete')
...
        WHEN event_name IN (..., 'replacement_rejected', 'substitution_rejected', 'sub_rejected', 'sub rejected')
```

and the approving list at 266 should get `'sub_approved', 'sub accepted'` for the same reason, which is a guess `[inferred]`, because the README names only `sub_rejected`.

- **How it works:** the vocabulary mapping is a closed list, so a new word needs a new entry. A sturdier way is the gold's method: delete everything that is not a letter, then match by `LIKE '%word%'`.

## 9. Timestamp offsets in other shapes

- **Your code** (`dag.sql` 301-303, 335-337): handles `+HH` (like `-07`) and falls back to `strftime`, which reads `+HH:MM` but returns NULL for `-0700`.
- **Gold code** (`gold_submit.sql` 45-48): rewrites `+HH`, `+HHMM` and ` UTC` to `+HH:MM`.
- **Why it matters [inferred]:** the README only says "the phone's own clock with its offset from UTC", so I cannot tell which offset shapes appear. A NULL `event_time` makes a delivered time missing and a tip lose its place in the order. Treat this as a suspect to check, not a proven loss.
- **After** `[untested]`: add one `WHEN` before the `ELSE` that handles `[+-][0-9]{4}$` by inserting a colon, as gold line 47 does.

## Not compared

- Nothing in the gold was missing: it is a complete file (176 lines). Its first 40 lines are only the DAG header.
- The README does not say how the platform builds the `scans` snapshot between runs, so I could not check how much of section 2 your history already covers. Test it with a day that is sent twice.

## Recommended pattern for SQL weeks like this

1. **Keep every copy of every raw row** in history, with the load stamp in the key, so a resent day is something you can choose from later, not something you already threw away.
2. **Make each key canonical once, at the edge** (digits-only codes, order numbers without `#`, one timestamp form, one vocabulary), and join only on canonical keys. Most of your lost points come from a join that finds nothing.
3. **Decide "who wins" at read time in the last task** (newest copy of a day, newest tip by its own time, newest price at order time). Do not decide it while loading.
4. **Parse a number from its meaning, not from its shape:** keep the minus sign, convert the unit, divide the offer.

## Checklist

- Does every `regexp_like(...)` that accepts a value also accept the sign, the unit and the symbol that the README mentions?
- Is there a join whose two sides were cleaned in different ways?
- Does "first copy wins" appear anywhere? Ask whether the later copy is the corrected one.
- Does any list of words have a README word that is missing from it?
- Did I run each change on a small table before relying on it?
