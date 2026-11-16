# Week 9 – The Basket: Teaching Review of `dag.sql`

## 1. Challenge and result

This is a SQL/DAG challenge, not a Python challenge. The execution contract is declared in the header of `dag.sql`; the submission builds one finance row per order from order events, shopper scans, and nightly price snapshots.

| Metric | Result |
|---|---:|
| Score | 0.6682 |
| Rank | #2 of 5 (top 40%) |
| Rows built | 17,036 / 17,036 |
| Statements | 7 |
| Work per raw row | 2.1× median |
| Scored | 2026-11-15 |

The output is structurally complete, but several columns still have substantial correctness gaps.

| Output | Correct | Wrong | Missed | Main signal |
|---|---:|---:|---:|---|
| `subtotal` | 38% | 10,612 | 0 | Pricing and scan interpretation |
| `items` | 78% | 3,696 | 0 | Weighted items, reversals, and replacements |
| `tip` | 87% | 2,153 | 0 | Currency text and late-arriving changes |
| `delivered_at` | 94% | 0 | 950 | Event vocabulary and event history |
| `status` | 100% | 20 | 0 | Reported correct rate is high, but 20 wrong rows remain |
| `order_id` | 100% | 0 | 0 | Current output normalization is effective for scored rows |

**How to read the metrics:** “Wrong” means a value was produced but did not match the expected value. “Missed” means the output value was absent where the grader expected one. This distinction matters: subtotal and items are primarily calculation problems; delivered_at is a coverage problem.

## 2. Understand the DAG before changing SQL

The current DAG keeps the following model/task names:

```text
order_events
    └── normalize_order
          └── order_events_history ───────────────┐
                                                  │
scans                                         │
    └── normalize_scan                            │
          └── scans_history ──────────────────────┤
                                                  ├── order_charges
prices                                            │
    └── normalize_price                           │
          └── prices_history ─────────────────────┘
```

The roles are different:

- **Normalize tasks** clean raw identifiers, text nulls, numeric fields, and timestamps.
- **History tasks** retain the records needed after source tables change or expire.
- **order_charges** combines the histories, resolves event state, selects the price applicable when the order was placed, and aggregates scan lines into one order row.

The DAG header currently declares `schedule: "0 */5 * * *"`, which runs at 00:00, 05:00, 10:00, 15:00, and 20:00. Preserve this five-runs-per-day cadence. The recommendations below are changes to the existing tasks and their SQL, not a request to add models or rename tasks.

## 3. Highest-impact findings

### 3.1 Price and barcode interpretation explain most subtotal errors

**Evidence in the submission**

The `normalize_price` task accepts a price only when it matches a plain unsigned decimal:

```sql
CASE
    WHEN regexp_like(price, '^[0-9]+([.][0-9]+)?$')
    THEN CAST(price AS DECIMAL(18, 6))
    ELSE NULL
END AS price
```

That rejects the shelf-tag representation `2/5.00`. It means “two for $5.00”, or $2.50 per item; it is not a price of $25.00 and should not be parsed by simply removing punctuation.

The final line calculation also joins a scan code directly to the price code:

```sql
LEFT JOIN pr ON pr.code = s.code
```

That misses a 12-digit UPC represented by the older app as a 13-digit EAN with a leading zero. It also does not decode variable-weight deli labels whose barcode contains the item and price.

**Why it matters**

The README says 70% of tables include leading-zero UPCs, 24.8% include a 2-for-$5 offer, and 32% include deli labels. The output metric is consistent with a broad pricing interpretation problem: only 38% of subtotal values are correct.

**Teaching pattern**

Normalize the identifier on both sides before joining, but retain the original value long enough to identify special label formats. Treat the offer format as a separate parsing rule rather than stripping characters blindly.

Illustrative normalization pattern:

```sql
CASE
  WHEN length(code_digits) = 13 AND substr(code_digits, 1, 1) = '0'
    THEN substr(code_digits, 2)
  ELSE code_digits
END AS normalized_code
```

For a `2/5.00` offer, parse the quantity (2) and total offer price (5.00), then derive unit price (2.50). Do not turn the text into `25.00`.

For a deli label, identify the label format first and extract the embedded cents from the documented barcode positions. Do not expect that code to exist in the ordinary price list.

**Recommended change:** improve the existing `normalize_price` and `normalize_scan` tasks, and use normalized codes in the existing `order_charges` join. Do not add a new SQL model.

### 3.2 Weighted items need a different item-count rule from ordinary items

**Evidence in the submission**

The current `lines` expression sets weighted items to one only when `pr.sold_by = 'lb'`:

```sql
CASE
  WHEN pr.sold_by = 'lb' THEN 1
  ELSE COALESCE(s.qty, 1)
END AS items
```

The price lookup can fail for a weighted item when the barcode is in EAN form, when it is a store label, or when the item is not present in the current price snapshot. If the lookup fails, the code no longer knows that the product is sold by weight.

The weight calculation also uses `COALESCE(s.weight_lb, s.qty, 0)` without converting an ounce-formatted reading such as `20.32 oz` into pounds.

**Why it matters**

A weighed product counts as one purchased item regardless of whether its measured weight is 0.4 lb or 2.3 lb. Its subtotal is weight multiplied by the price per pound. Those are two separate calculations.

**Teaching pattern**

1. Normalize the scan's weight and unit before aggregation.
2. Convert ounces to pounds using `ounces / 16.0`.
3. For an item sold by weight, count one item for a positive net quantity/weight and apply a negative count when a reversal removes the item, following the challenge's scan semantics.
4. Calculate cents from the normalized weight and the as-of unit price; round at the line level as required by the challenge.

Illustrative conversion:

```sql
CASE
  WHEN lower(trim(weight_text)) LIKE '%oz'
    THEN parsed_weight / 16.0
  ELSE parsed_weight
END AS weight_lb
```

Do not use a permissive numeric cast as a substitute for unit parsing: extracting `20.32` from `20.32 oz` without converting it produces a value 16 times too large.

### 3.3 Negative scans are valid reversals, not malformed quantities

**Evidence in the submission**

The current quantity parser accepts only unsigned values:

```sql
WHEN regexp_like(qty, '^[0-9]+([.][0-9]+)?$')
THEN CAST(qty AS DECIMAL(18, 6))
ELSE NULL
```

A valid `-1` scan is therefore converted to NULL. The README explicitly describes a shopper scanning one extra unit and then recording a `-1` scan to take it back out.

**Why it matters**

Discarding a reversal leaves the original scan charged. It can inflate both item count and subtotal. Negative values are part of the business event model, not necessarily bad source data.

**Recommended change**

Allow a leading minus sign in the numeric validation, while still rejecting malformed strings. Preserve the sign through line aggregation. Test a pair of scans for the same order/item (for example, +1 followed by -1) and verify the net charged quantity is zero.

### 3.4 Scan history currently keeps the first version of a batch, but the source resends whole days

**Evidence in the submission**

The `normalize_scan` incremental branch excludes any batch already present:

```sql
WHERE _batch_id NOT IN (
  SELECT batch_id FROM {{ this }} WHERE batch_id IS NOT NULL
)
```

The task then chooses the earliest load for each batch:

```sql
MIN(loaded_at_utc) OVER (PARTITION BY batch_id) AS first_load
```

The downstream `scans_history` task is also configured as an incremental merge keyed by `scan_id`.

**Why it matters**

The README says a store can resend the entire day's file under a newer load stamp after reconciling against the register. The replacement snapshot can contain new scans and omit scans that were not ultimately charged. If the pipeline keeps only the first batch version, or merges a later snapshot by scan ID without removing rows that disappeared, the final history is not the corrected daily snapshot.

This is not the same as a duplicate file transfer. An identical retry can be deduplicated; a corrected whole-day resend must be treated as a replacement for that day's prior snapshot.

**Recommended change**

Keep the existing `normalize_scan` and `scans_history` task names, but revise their incremental semantics so the latest complete version of each business-day batch replaces the prior version. Use the batch/day plus load stamp to identify the snapshot version. Ensure a later snapshot removes records absent from that snapshot, while preserving the chosen historical versions needed for downstream reproducibility.

Do not use `NOT IN` for a nullable anti-join unless NULL behavior is explicitly handled. A `NOT EXISTS` predicate is safer when the source or target key may contain NULLs.

### 3.5 Tip values need currency cleanup and customer-event ordering

**Evidence in the submission**

The final `tips` CTE selects the latest `placed` or `tip_changed` event using event time and write time, then the final output treats `tip` as a numeric value. The raw `detail_tip` text is not normalized to handle the README's examples `$5.00` and `5.00 USD`.

**Why it matters**

A currency symbol or trailing currency code makes a plain numeric cast fail or produce NULL. The README also describes an offline phone update that arrives after a newer website update. The latest row written is not necessarily the last tip the customer set.

**Teaching pattern**

- Normalize the amount by removing the supported currency decoration, not by accepting arbitrary malformed characters.
- Parse the numeric portion only after validating the expected format.
- Rank customer changes by the timestamp representing when the customer made the change. Use ingestion/write time only as a deterministic tie-breaker, not as the primary definition of “latest”.

Illustrative ranking:

```sql
ROW_NUMBER() OVER (
  PARTITION BY order_id
  ORDER BY event_time DESC, written_at DESC, event_id DESC
) AS rn
```

The current ordering already uses event time before write time, which is the right direction. The main gap is parsing the amount and verifying that every tip-change event vocabulary maps into the same canonical event family.

### 3.6 Event vocabulary and delivery coverage explain missing delivered_at values

**Evidence in the submission**

The event normalization uses a finite alias map. The README explicitly lists `DELIVERED` and `dropoff_complete` as values emitted by different apps. The canonical delivery aliases in the current SQL include several delivery variants, but the mapping must be checked against every vocabulary actually listed in the challenge data.

The final output returns `o.delivered_at` for every order whose derived status is delivered. If a delivery event was not recognized, the order can have delivered status logic that does not have a usable delivery timestamp.

**Why it matters**

The grader reports 950 missed `delivered_at` values and no wrong values. That pattern points to missing event coverage rather than a timestamp that is consistently calculated incorrectly.

**Recommended change**

Extend the existing event normalization CASE expression to map the documented delivery aliases, including `dropoff_complete`, to one canonical event name. Also map the documented replacement, cancellation, reinstatement, and tip aliases consistently. Keep raw event text available during development so unknown values can be counted rather than silently dropped.

Validate delivery timestamps independently from status: an order's status and its delivery timestamp are related but are not interchangeable.

### 3.7 Order IDs with a leading # should normalize to the same key

The README says some shoppers type an order number as printed, including the leading `#`. The current order ID parser accepts only digits:

```sql
WHEN regexp_like(order_id, '^[0-9]{1,8}$')
THEN ...
ELSE NULL
```

A value such as `#12345` therefore becomes NULL and cannot join to the corresponding order. Normalize the documented prefix before validating the digit count and padding the identifier. Apply the same normalization consistently to scans and order events.

The current score reports 100% correct for `order_id`, but the README says this condition occurs in 9% of tables and only 65% of those cases were recovered. A high column-level score does not mean this edge case is solved; inspect condition-level recovery as well.

## 4. Price history and as-of joins

The DAG correctly recognizes that a nightly price snapshot is history, not just a current lookup table. The `prices_history` task retains versions keyed by code and load timestamp. The final query uses `LAG` to identify price change points and `LEAD` to create validity intervals.

The key business rule is: **charge the price that was in force when the order was placed**, not the latest price and not automatically the price from the same calendar date.

The current interval predicate is:

```sql
o.placed_at > pr.vfrom
AND (pr.vto IS NULL OR o.placed_at <= pr.vto)
```

Check the interval boundaries carefully. A conventional half-open interval is `placed_at >= vfrom AND placed_at < vto`. The correct boundary convention must match how the price snapshot's effective time is defined. The current strict lower bound can exclude an order placed at the exact first timestamp; the inclusive upper bound can assign an order at a change timestamp to the preceding price. Test both sides of every price-change boundary before changing it.

Also test the README's cases where an item is removed from a later price list, a replacement item is priced days after first appearing, and one day's price snapshot is missing. These cases require retaining sufficient history and defining a deliberate fallback; a same-day inner join is not enough.

## 5. Existing strengths to preserve

- The DAG separates raw normalization, history retention, and final business aggregation.
- Event history is retained by event ID, which is important because the source event table has a six-hour retention window.
- Price history is retained by code and load timestamp, enabling historical price selection.
- The final query aggregates scan lines to order grain and left-joins totals so orders with no charged lines can still appear.
- Event ordering uses event time before write time for tip and replacement decisions; preserve that semantic distinction.
- The DAG already runs five times per day. Keep that cadence and preserve all existing task/model names.

## 6. Performance considerations

The README reports work per raw row at 2.1× the median. Prioritize correctness first, then measure:

1. Normalize each source field once in its existing normalization task; avoid repeating expensive trimming, regular expressions, and timestamp parsing in downstream joins.
2. Filter event history to the required order window as early as correctness permits, while retaining the events needed to resolve cancellations, reinstatements, tips, and delayed delivery updates.
3. Ensure join keys have the same normalized representation before joining; do not wrap both sides of a large join in repeated transformations.
4. Reduce price history to actual change points before interval matching, as the current `p1`/`p2` approach intends.
5. Check row counts and key uniqueness after each history task. A faster query that loses a corrected snapshot is not an improvement.

Do not add new SQL models for these optimizations. Work within the existing task graph.

## 7. Validation plan

Run these checks against the challenge runner after making changes. The SQL below is illustrative and should be adapted to the runner's available source/history tables.

### A. Source and normalized-key coverage

- Count raw scan rows, normalized scan rows, and rows rejected because the scan ID or order ID could not be parsed.
- Count order IDs beginning with `#` before and after normalization.
- Count 13-digit EAN codes beginning with zero and verify they map to the same normalized key as their 12-digit UPC.
- Count each raw event vocabulary and confirm no documented event alias remains unmapped.

### B. Snapshot replacement behavior

Create or identify a test day with two complete snapshots:
- Snapshot 1 contains scans A, B, and C.
- Snapshot 2 contains scans A and C, plus a new scan D.

After processing snapshot 2, the active snapshot for that day should contain A, C, and D, not B. A byte-for-byte retry of snapshot 2 should not duplicate rows. Confirm the behavior remains correct across repeated five-times-daily runs.

### C. Arithmetic edge cases

| Case | Expected behavior |
|---|---|
| One weighted item, 1.5 lb at $1.99/lb | 1 item; subtotal $2.99 after line rounding |
| 20.32 oz | Convert to 1.27 lb before pricing |
| Quantity +1 and reversal -1 | Net quantity zero |
| `2/5.00` offer | $2.50 per item |
| Leading-zero EAN-13 | Match corresponding UPC |
| Store label beginning with 2 | Decode embedded item price |
| Tip `$5.00` | Numeric tip 5.00 |
| Tip `5.00 USD` | Numeric tip 5.00 |
| `#12345` | Same normalized order key as `12345` |

### D. Temporal and event-state checks

- Place an order immediately before and exactly at a price effective-time boundary; verify the correct price on both sides.
- Place an order before midnight and after midnight but before the new price snapshot; verify the price follows effective time, not calendar date.
- Test a missing daily price snapshot and a product removed from a later snapshot.
- Test a delayed delivery event, `dropoff_complete`, a cancellation followed by reinstatement, and an order cancelled after scans were recorded.
- Test a tip change made offline that arrives after a later website update; the customer-event ordering should win over arrival order.

### E. Final output contract

- Exactly one row per eligible order.
- No duplicate `order_id`.
- Cancelled orders have zero charged items and subtotal, and no delivered timestamp.
- Delivered orders have a valid delivered timestamp when a recognized delivery event exists.
- No unexplained NULLs in `subtotal`, `items`, or `tip`.
- Compare all six output columns with the grader and inspect condition-level recovery, not just overall accuracy.

## 8. Scope and confidence

This review is a static comparison of the repository's `README.md`, `dag.sql`, and `gold_submit.sql`, with the README's challenge conditions treated as the business contract. It is not a successful runtime validation. The SQL fragments above illustrate the required logic; they are not presented as a fully tested drop-in replacement.

The highest-confidence findings are the explicit mismatches between the submission and README: unsigned-only quantity parsing, plain-decimal-only price parsing, exact barcode matching, first-version-only scan batch handling, missing ounce conversion, and digit-only order ID parsing. The exact contribution of each issue to each wrong row requires targeted test runs.

**Change boundaries:** keep the existing five-runs-per-day schedule; keep the existing task/model names; do not introduce new SQL models; and do not modify `gold_submit.sql`.