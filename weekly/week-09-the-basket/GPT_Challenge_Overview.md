# Week 9: The Basket — Challenge Overview

> A conceptual guide to the challenge, its data-engineering patterns, and the skills it exercises. This is not an execution report.

## 1. Problem statement, goal, and output grain

A grocery-delivery customer places an order in an app. A shopper picks products from store shelves and scans them into bags. A driver delivers the order. Finance needs one reliable record per order showing its final status, delivery time, charged item count, subtotal, and tip.

The challenge combines three operational sources:

- **`order_events`** — order lifecycle and customer/support events, including placement, delivery, cancellation, reinstatement, tip changes, and replacement decisions.
- **`scans`** — item-level scan records from shoppers, including quantities, weights, product codes, and batch/load metadata.
- **`prices`** — nightly snapshots of store prices and selling units.

The target population is orders placed from **2026-10-16 inclusive through 2026-11-14 inclusive** (the SQL uses an exclusive upper bound of 2026-11-15).

The final output grain is **one row per order**:

| Column | Meaning |
|---|---|
| `order_id` | Canonical order identifier |
| `status` | Final order status, including cancellation/reinstatement semantics |
| `delivered_at` | Delivery time where applicable |
| `items` | Number of charged item units; a weight-sold product counts as one item per line/scan, not one item per pound |
| `subtotal` | Amount charged for the picked items |
| `tip` | Final customer tip after subsequent changes |

The key business rules go beyond summing scans:

- A cancelled order is not charged; an order can later be reinstated.
- A scan can represent a quantity adjustment, including a negative quantity when an item is removed.
- Weight-priced products are charged by weight and price per pound, while still counting as one item.
- Some products use variable-weight labels whose barcode encodes the price.
- Promotions such as 2-for-$5 must be interpreted as a unit price, not as a concatenation of digits.
- An order uses the price version in effect when it was placed, not necessarily the latest price snapshot or the snapshot from the same calendar date.
- Replacement scans can be declined and later approved; the final decision applies to the specific scan.
- Tips can change after delivery. The winning value is based on when the customer set it, not necessarily the row that arrived last.
- Source extracts can be delayed, replayed, restated, or partially missing. The pipeline must preserve enough history to reconstruct the correct order.

## 2. Domain context and prerequisites

This challenge combines grocery retail, order management, inventory/merchandising, shopper operations, delivery tracking, and financial reconciliation.

- **Order lifecycle:** An order can be placed, delivered, cancelled, deleted, or reinstated. These are state transitions, not independent facts to count blindly.
- **Picking scan:** A scan records an item the shopper handled. It does not by itself prove that the customer was charged for it.
- **Replacement/substitution:** When an ordered product is unavailable, a shopper may scan a replacement. The customer can accept or reject it, potentially changing their decision later.
- **UPC/EAN/PLU:** Product identifiers can use different barcode standards. A UPC-A may appear as a 12-digit value or as a 13-digit EAN with a leading zero. PLUs are short produce codes.
- **Variable-weight barcode:** A deli/meat label can encode the item and a price amount in its digits. Such a product may not appear in the ordinary shelf-price list.
- **Price snapshot:** A nightly price file is a point-in-time copy. To answer what an order paid, the pipeline needs historical price versions and an explicit as-of rule.
- **Sold by each versus sold by weight:** Item count and monetary calculation are different. A pound-priced item is one item for the `items` metric, but its line charge is weight multiplied by price per pound.
- **Event time versus write/arrival time:** `event_at` describes when the business event happened; `written_at` describes when the order service recorded it. A delayed phone sync can arrive after a newer web change.
- **Batch time versus event time:** A scan's batch/load metadata describes file delivery, not necessarily when the shopper performed the scan.

Conceptual flow:

```text
order_events ── lifecycle, tip and replacement decisions ──┐
                                                           │
scans ───────── item identity, quantity and weight ─────────┼─ one row per order
                                                           │
prices ──────── price history and as-of-order lookup ───────┘
```

## 3. Execution contract and challenge type

The README identifies `dag.sql` as the graded submission. The folder contains `dag.sql` and `gold_submit.sql`, not the Python `handler.py` / `gold_submit.py` pair. The authoritative challenge type is therefore **SQL/DAG**.

The submitted DAG declares these stages:

1. `normalize_order` → `order_events_history`
2. `normalize_scan` → `scans_history`
3. `normalize_price` → `prices_history`
4. `order_charges`, which combines the three histories into the final order-level output

The submitted DAG schedules the pipeline every five hours. Its source-history tasks use incremental merge patterns, with event and scan identifiers or `(code, loaded_at_utc)` as keys. The final `order_charges` task is materialized as a table.

The reference `gold_submit.sql` uses a different schedule and materialization design: it retains event history, overwrites scan partitions, retains price snapshots by load partition, and rebuilds the final order-charge table. This is an architectural alternative. The right choice depends on runner semantics, source retention, and whether changed historical data can be safely reprocessed.

## 4. Difficulty assessment

**Difficulty: 5 / 5 — Advanced**

This rating describes the challenge contract, not any particular execution outcome.

| Dimension | Assessment | Evidence from the contract |
|---|---|---|
| Conceptual complexity | Very high | Three source systems describe different aspects of an order; the result reconciles lifecycle state, picked items, prices, substitutions, and tips. |
| Edge-case density | Very high | Barcode variants, promotions, variable-weight labels, unit conversions, timestamp formats, late changes, missing snapshots, and replayed files. |
| Correctness requirements | Very high | Small mistakes change financial amounts or item counts. Event arrival order can differ from business-event order. |
| Performance and scale | High | History must be retained and queried across orders, scans, and price versions. Window functions, temporal joins, and deduplication need appropriate keys and partitions. |
| Operational complexity | Very high | The order-event table has short retention; scans can arrive late or be resent as whole-day corrections; price snapshots can be missing; incremental runs must handle backfills safely. |

The core difficulty is not query length. It is reconstructing the financially correct state from mutable, delayed, differently-grained records.

## 5. Main problems and traps encoded in the README

### A. Order lifecycle and event semantics

- **Different vocabularies:** Client apps and support tools use different spellings and phrases for delivery, cancellation, tip updates, and replacement decisions.
- **Cancellation and reinstatement:** A cancellation is not necessarily terminal. A later reinstatement can make the order active again.
- **Deleted events:** The order service can delete events, so a pipeline that reads only the current live table may lose earlier lifecycle evidence.
- **Delivery time:** A driver may record delivery offline and sync later. Write time is not the time the bags reached the customer.
- **Order identifiers with `#`:** A shopper may type the printed order number including a prefix. It must still match the canonical order ID.
- **Replacement decisions:** A customer can first decline a replacement and later accept it. The latest decision for the specific scan determines whether it is charged.

**Lesson:** Normalize event names, identifiers, and timestamps, then derive final state using business-event ordering and an explicit tie-breaker. Do not treat every event as an independent current-state fact.

### B. Scan history, corrections, and quantity

- **Same scan twice:** A transfer retry can duplicate the same scan within a file.
- **Whole-day resend:** A store can resend the day's entire scan file under a newer batch stamp.
- **Removed scan:** A corrected day can omit a scan that appeared in the earlier copy. Merging rows by scan ID cannot infer that omission; replacing the logical day can.
- **Negative quantity:** A shopper can scan an extra unit and then remove it with a negative scan. Quantity is the net sum.
- **New and old app schemas:** The newer app may populate `weight_lb` while the older app leaves it missing or writes textual NULL.
- **Delayed copy:** A file can arrive after the run has begun. Looking only at the current day's batch can permanently miss it.
- **Offline scans:** Scan load time is not necessarily business event time.

**Lesson:** Choose the correct replacement unit (often a whole batch/day partition), deduplicate repeated deliveries, and preserve the ability to incorporate late data.

### C. Product-code normalization

- **Leading-zero UPC/EAN:** A 12-digit UPC can appear as a 13-digit EAN with a leading zero. This can prevent a price join and hide a variable-weight barcode prefix.
- **Variable-weight labels:** Some labels encode a product identifier and a price in cents. They are not ordinary UPCs and may not exist in the price snapshot.
- **PLU and product formats:** Produce codes and regular UPCs have different lengths and semantics.
- **Order/scan key formatting:** Valid IDs may contain prefixes, punctuation, or leading zeros that need deliberate canonicalization.

**Lesson:** Preserve the raw code, classify the barcode format, and canonicalize only according to known rules. Avoid indiscriminately stripping digits if doing so can merge distinct identifiers.

### D. Price history and promotions

- **Price changed after order:** The latest price list is not necessarily the price the customer paid. The correct price is the version effective when the order was placed.
- **Ordered before morning publication:** A price change published in the morning takes effect then; an order placed after midnight but before publication may still use the previous snapshot.
- **Missing daily price list:** If a snapshot is absent, the previous known price remains in force.
- **Discontinued product:** An item can disappear from later snapshots while older orders still require its historical price.
- **New shelf find:** A replacement item may be scanned before merchandising adds it to the price list. Its first recorded price can apply to that order.
- **2-for-$5 promotion:** The displayed offer must be parsed semantically and converted to a unit price. Removing punctuation and casting remaining digits produces the wrong amount.

**Lesson:** Build effective-dated price intervals and use a temporal as-of join. A calendar-day join or latest-snapshot join is not enough.

### E. Weight and monetary arithmetic

- **Sold by pound:** Line charge is weight multiplied by price per pound, rounded to cents.
- **Ounces in a pounds field:** Some scales report ounces even when the destination field is named `weight_lb`; the unit must be parsed and converted.
- **Item count differs from weight:** A pound-priced line contributes one item, regardless of weight.
- **Negative quantity:** Corrections must reduce quantity and value rather than be discarded as invalid.
- **Currency-formatted tips:** Values may include `$` or a trailing `USD`; parse them before numeric conversion.
- **Rounding:** Monetary line calculations need an explicit decimal/cents policy to avoid floating-point drift.

**Lesson:** Parse quantity, unit, price, and currency independently. Use exact decimal or integer-cent arithmetic and round at the business-defined line level.

### F. Tips and out-of-order updates

- **Post-delivery changes:** A customer can change the tip for several days after delivery.
- **Multiple time representations:** Driver timestamps can be epoch milliseconds; customer timestamps can be ISO-like strings with UTC offsets.
- **Late phone sync:** A phone may queue an earlier change and upload it after a later website change. The last row written is not necessarily the last value set.

**Lesson:** Normalize timestamps to comparable instants and order changes by the timestamp representing when the customer set the value. Keep write time as a tie-breaker or lineage field, not as a substitute for event time.

## 6. Submitted SQL versus the reference solution

This is a code and design comparison. The reference is one implementation, not a list of mandatory CTE names or required coding style.

| Area | Submitted `dag.sql` | Reference `gold_submit.sql` | Engineering implication |
|---|---|---|---|
| Pipeline architecture | Three normalization stages, three history stages, and a final `order_charges` table. | Retains raw histories with distinct/partition-overwrite patterns and builds the final table with normalization CTEs. | The submission makes normalization explicit and reusable; the reference keeps more parsing in the final query and uses partition replacement for scan corrections. |
| Order events | Canonicalizes a fixed list of aliases, parses several timestamp formats, extracts numeric tips and replacement scan IDs, and deduplicates by event ID. | Uses broader pattern-based event classification, more flexible order-ID cleanup, and ranks lifecycle/tip/replacement events using event time, write time, and event ID. | Exact alias maps are easier to audit; pattern matching can cover more variants but needs safeguards against false matches. |
| Scan IDs and order IDs | Validates scan IDs against a constrained hex format and canonicalizes numeric order IDs to eight digits. | Uses distinct raw scans and performs more flexible cleanup of order and scan-related identifiers in later CTEs. | Strict parsing is safe for known formats but can reject undocumented variants. Canonicalization should follow the source contract. |
| Scan replay strategy | `scans_history` excludes batch IDs already present, retaining the first-seen batch rather than treating a later whole-day batch as a replacement. | Uses `insert_overwrite` partitioned by batch/load metadata and selects the latest load within a batch-day group. | Whole-day restatements require replacement semantics or explicit reconciliation. A simple append/merge can preserve scans that a corrected file intentionally removed. |
| Price history | Normalizes prices and retains history keyed by code and load time. | Retains price snapshots and constructs price change points using `LAG`. | Both recognize that historical prices matter. The effective-time boundary must be precise. |
| Promotions and price parsing | Accepts numeric decimal price strings and stores a `sold_by` value of `each` or `lb`; the final query multiplies price by 100. | Parses numeric portions of price strings and handles broader source forms. | The submitted parser does not visibly decode `2/5.00` into a per-unit offer price. Blind punctuation stripping is also unsafe without semantic rules. |
| Variable-weight labels | Detects a code beginning with `2` and extracts digits from the code for the charge. | Normalizes code digits, removes leading UPC zeros, and detects 12-digit variable-weight labels after normalization. | The reference more explicitly handles the interaction between 13-digit EAN representation and store-label classification. |
| Weight and quantity | Uses decimal casts for `qty` / `weight_lb`. Pound-priced items count as one and use weight or quantity as a fallback. | Aggregates weighted line counts as one per nonzero weighted line and calculates cents from weight or quantity. | The submission has the basic weighted-item model, but its visible parser accepts plain numeric weight and does not parse an `oz` suffix or convert ounces to pounds. |
| Replacement decisions | Selects the latest decline/approval by event time and write time for each replacement scan, then excludes scans whose latest state is declined. | Classifies replacement events and ranks the latest decision per scan using event/write time and event ID. | Both model decisions at scan grain. A robust tie-breaker matters when events share timestamps. |
| Tip selection | Chooses the latest tip event by event time and write time, after parsing a restricted plain-decimal format. | Ranks placed/tip events using parsed event time, write time, and event ID, then parses currency-formatted tip text at output. | The reference includes a deterministic final tie-breaker and broader value parsing. The semantic rule remains event time, not arrival order. |
| Final order status | Uses aggregate placed/delivered/cancelled/reinstated timestamps and excludes deleted orders. | Ranks lifecycle events and derives the latest cancellation/reinstatement state. | Both use event history; explicit ranking makes the last cancellation/reinstatement decision easier to reason about. |
| Output grain | Builds orders and left-joins aggregated item totals and latest tips. | Left-joins aggregated scan lines to the final order set. | Both target one row per order. Every intermediate join must be checked for one-to-many multiplication. |

### What the submission does well

- Decomposes the DAG into normalization, history, and final aggregation stages.
- Uses explicit merge keys for event, scan, and price history.
- Trims whitespace and normalizes a broad set of textual NULL markers.
- Converts numeric timestamp representations to a common UTC representation.
- Canonicalizes order IDs and validates event/scan identifiers before they enter history models.
- Maps several common event aliases into canonical event names.
- Uses window functions to deduplicate events and rank replacement decisions and tips.
- Preserves price snapshots by product code and load time rather than joining only to the current price.
- Separates order-level aggregation from scan-level line calculations.
- Uses decimal types for parsed quantities and weights, and distinguishes weighted items from each-priced items.

### What the reference handles more explicitly

The reference has broader event-name recognition and identifier cleanup, a scan-history strategy designed around partition replacement, additional barcode normalization, and more flexible price/tip parsing. It also ranks lifecycle and tip decisions with a deterministic event-ID tie-breaker and explicitly models whole-day scan reloads.

Flexible parsing is not automatically superior: broad regular expressions can classify unintended values. A production implementation should prefer explicit source contracts, retain raw values, and count unknown/unparsed cases.

## 7. Technical concepts worth studying

1. **Data grain and dimensional modeling** — Raw sources have event, scan, and product-snapshot grains; the output is order grain. Define grain before joining to prevent row multiplication.
2. **Event sourcing and state reconstruction** — Order status, tip, and replacement acceptance are derived from event histories. Separate the event log from current business state.
3. **Temporal joins / effective dating** — Price snapshots become validity intervals. An order must join to the price effective at `placed_at`, not simply the same date or latest row.
4. **Late-arriving data and event-time ordering** — Offline delivery/tip events can arrive after newer changes. Distinguish event time, written time, and load time.
5. **Incremental materialization strategies** — Merge is useful for keyed corrections; insert-overwrite is useful when a whole partition is restated. Understand what each strategy can and cannot delete.
6. **Idempotency and replay handling** — Reprocessing a file must not double-count scans or charges. Batch identity and scan identity solve different problems.
7. **Window functions** — `ROW_NUMBER` selects latest state; `LAG` identifies price change points; `LEAD` can build effective intervals. Partition/order keys encode business policy.
8. **Barcode and identifier normalization** — UPC/EAN leading-zero equivalence and variable-weight labels require format-aware parsing.
9. **Exact monetary arithmetic** — Use decimal or integer cents, define line-level rounding, and avoid floating-point accumulation for financial totals.
10. **Unit-aware measures** — Weight, quantity, and item count are distinct measures. Parse units and convert before multiplying.
11. **Semi-structured/text parsing** — Currency symbols, suffixes, promotion notation, and timestamp formats require validation rather than blind character removal.
12. **DAG orchestration and source retention** — A six-hour source TTL means ingestion cadence and durable history are part of correctness, not merely scheduling details.

## 8. Additional production-learning angles

### Intended logical model

A robust design can be reasoned about as four logical layers:

- **Normalized order events:** canonical order ID, event type, event time, write time, parsed tip, and replacement scan reference.
- **Normalized scans:** canonical scan/order/product identifiers, quantity, weight plus unit, batch identity, and load time.
- **Price history:** product/store price, selling unit, and effective interval derived from snapshots.
- **Order charges:** one row per order, with final lifecycle state, final tip, accepted scan lines, item count, and subtotal.

These are logical responsibilities, not required physical table names.

### Assumptions to make explicit

- Is the authoritative placement time the first `placed` event or a later corrected placement?
- What happens when two lifecycle events have the same event timestamp?
- Does a replacement decision refer to a scan ID, an order line, or a product code?
- Are repeated scan IDs always duplicate deliveries, or can a scan ID be revised?
- Does a missing daily price snapshot mean the previous known price remains effective until the next snapshot?
- Is a price effective from snapshot load time, a business-effective timestamp, or a scheduled publication time?
- Does a variable-weight label encode a fixed number of cents, and what is its exact digit layout?
- How should weighted-item count behave when net weight is zero or negative?
- Which timestamp decides the latest tip: customer-set time, event time, or a source-specific field?
- How are taxes, discounts, delivery fees, and refunds treated? The described output focuses on item subtotal and tip; do not assume additional financial fields.

### Correctness versus performance

A full rebuild of order charges is conceptually simple because late events, replacement decisions, and price corrections can affect old orders. Its cost grows with retained history.

Incremental models reduce repeated work, but need an affected-order strategy. A new tip event can affect one old order; a corrected scan batch can affect every order in that batch; a price snapshot correction can affect orders placed during its effective interval. A robust design should identify and recompute impacted orders rather than process only today's order IDs.

### Observability and debugging as general skills

Useful production measures include:

- Unknown order-event names by source application
- Invalid or uncanonicalizable order IDs, scan IDs, and product codes
- Percentage of timestamps parsed by representation
- Duplicate scan IDs and repeated batch deliveries
- Number of batches received after the expected ingestion window
- Missing price snapshots and products with no matching effective price
- Price strings that fail promotion/currency parsing
- Weight values with unrecognized units
- Replacement scans with no corresponding decision event
- Orders whose item count or subtotal changes after a replay/backfill
- Output orders with no matching placement, delivery, or scan history

These are recommended observability metrics, not claims that the challenge runner supplies them.

### Failure modes to design against

- The six-hour order-event retention window deletes events before ingestion captures them.
- A delayed scan file is skipped because the DAG only reads the current batch date.
- A resent whole-day file is merged, leaving stale scans that the corrected file omitted.
- A one-to-many price join multiplies scan lines.
- A product code is normalized too aggressively and collides with another product.
- A price snapshot is joined by calendar date instead of effective time.
- A promotion string is parsed as a plain number.
- Ounces are interpreted as pounds.
- A weighted item is counted by weight rather than as one item.
- A delayed tip sync overwrites a newer customer decision because load time is mistaken for event time.
- A replacement scan remains charged after the latest customer decision declines it.
- Floating-point arithmetic introduces cent-level rounding differences.
- A rerun adds duplicate charges instead of replacing/recomputing affected orders.

## 9. Suggested learning plan and validation checklist

The following are **recommended tests derived from the README and SQL contract; they are not reported as executed tests**.

### Step 1 — Establish the grain and lifecycle

- [ ] Explain why the final output is one row per order rather than one row per scan.
- [ ] Draw the order lifecycle including cancellation and reinstatement.
- [ ] Explain why a scan is not automatically a charged item.
- [ ] Distinguish placement time, delivery event time, write time, and load time.

### Step 2 — Normalize IDs, events, and timestamps

- [ ] Do order IDs with and without `#` resolve to the same canonical key?
- [ ] Do 12-digit UPCs and their 13-digit leading-zero EAN representations match?
- [ ] Are variable-weight labels identified before ordinary UPC cleanup destroys their prefix?
- [ ] Do supported event aliases map to the intended canonical event?
- [ ] Do epoch milliseconds and ISO timestamps with offsets normalize to the same instant when they represent the same time?
- [ ] Does a timestamp parser reject malformed or ambiguous values instead of silently inventing a time?

### Step 3 — Validate scan history and corrections

- [ ] Does loading the same scan file twice leave the logical scan set unchanged?
- [ ] When a whole-day restatement omits a prior scan, does the pipeline remove that stale scan?
- [ ] Can a batch that arrives after the run begins still be ingested later?
- [ ] Does a negative scan reduce net quantity and subtotal?
- [ ] Do old- and new-app records with missing/textual-NULL weight values behave correctly?
- [ ] Are scan IDs unique at the intended source-event grain?

### Step 4 — Validate pricing and item arithmetic

- [ ] Does an order placed before a morning price publication use the prior price?
- [ ] Does a missing price snapshot carry forward the previous known price?
- [ ] Does a discontinued product still resolve to its historical price?
- [ ] Does a newly listed replacement product use the intended first effective price?
- [ ] Does a 2-for-$5 offer resolve to $2.50 per unit?
- [ ] Does a variable-weight label compute encoded cents without requiring a price-list match?
- [ ] Does a 13-digit EAN representation still identify a variable-weight label correctly?
- [ ] Does 16 ounces convert to one pound before pricing?
- [ ] Does a weighted line count as one item while its subtotal uses weight?
- [ ] Are line amounts rounded to cents using an explicit decimal policy?

### Step 5 — Validate order state, replacements, and tips

- [ ] Does cancellation produce zero charged items and zero subtotal?
- [ ] Does a later reinstatement restore the order's active state?
- [ ] Does a deleted order follow the documented exclusion rule?
- [ ] Does the latest replacement decision for a scan determine whether it is charged?
- [ ] Does a later approval reverse an earlier decline, and vice versa?
- [ ] Does a tip changed after delivery replace the earlier tip?
- [ ] Can an earlier phone change arriving late be prevented from overwriting a later web change?
- [ ] Are ties resolved deterministically with a documented secondary key?

### Step 6 — Validate DAG behavior and output invariants

- [ ] Does each task's unique key match its actual logical grain?
- [ ] Can a price-history join return more than one applicable price for a scan?
- [ ] Does every included order produce exactly one final row?
- [ ] Does each order's `items` equal the sum of charged line quantities under the weighted-item rule?
- [ ] Does each order's `subtotal` equal the sum of eligible line charges?
- [ ] Are cancelled orders represented with the intended null/zero conventions?
- [ ] Can a new event, scan correction, or price snapshot trigger recomputation of affected historical orders?
- [ ] Are retries and reruns idempotent?

## 10. Evidence and uncertainty

### Facts stated by the README

- The domain is grocery delivery and the business goal is a finance-ready row per order.
- The three sources are `order_events`, `scans`, and nightly `prices` snapshots.
- The order window is 2026-10-16 through 2026-11-14.
- The README describes source retention, whole-day scan resends, late files, event vocabulary differences, barcode variants, weighted products, price changes, promotions, replacement decisions, and delayed tip changes.
- The output columns are `order_id`, `status`, `delivered_at`, `items`, `subtotal`, and `tip`.

### Facts visible in the SQL files

- `dag.sql` embeds the DAG configuration and declares `normalize_order`, `order_events_history`, `normalize_scan`, `scans_history`, `normalize_price`, `prices_history`, and `order_charges`.
- The submitted `normalize_scan` parser accepts a constrained scan-ID form, normalizes numeric order IDs, parses decimal quantity/weight values, and derives a batch date from several batch string forms.
- The submitted `scans_history` incremental filter excludes batch IDs already present in target history.
- The submitted `normalize_price` stage parses numeric decimal price strings and recognizes `each` and `lb`.
- The submitted `order_charges` query uses order lifecycle aggregation, latest replacement decisions, price change points with `LAG`, and line-level aggregation.
- `gold_submit.sql` uses partition overwrite for scan history, broader event normalization, barcode normalization, price-history change points, and explicit item/tip/lifecycle ranking.

### Interpretations and uncertainty

- The README is the primary business contract. The reference is evidence of one solution approach; details found only in the reference should be checked against the brief and source schema before being treated as mandatory.
- The README says the newer scanner can send a weight value with its unit (for example, ounces) in a field named `weight_lb`. The submitted parser's visible numeric regular expression accepts a plain decimal; the visible reference extraction also strips nonnumeric characters rather than clearly interpreting the unit. Unit-aware conversion deserves an explicit test.
- The submitted scan history's batch exclusion appears to preserve the first batch version rather than replace a previously loaded whole-day batch. The README's removed-scan example requires a replacement/reconciliation rule; verify runner merge and batch semantics before choosing a strategy.
- The reference derives price change points and ranks candidate price rows around order placement. Its exact inclusive/exclusive boundary behavior should be tested against the morning publication rule.
- The README describes 2-for-$5 notation and currency-formatted tips. The submitted SQL's visible numeric-only parsers do not cover all those textual forms. Broad character removal is not a substitute for a format-aware parser.
- The README and SQL imply templated DAG execution and SQL date/JSON/regular-expression functions, but confirm the exact engine/runtime contract before assuming portability.
- Source fields and metadata are described from the README and referenced directly by SQL; no additional schema is assumed here.

## 11. Heuristic experience-equivalent estimate

These are heuristic skill-equivalence ranges for the work represented by the problem and SQL approaches. They are **not** the actual employment history of the challenge author or solution author, and they are **not** a reliable hiring-level verdict.

| Subject | Heuristic range | Rationale |
|---|---:|---|
| Problem described in the README | **3–6 years** of relevant data-engineering exposure | Requires multi-source reconciliation, event-state reconstruction, effective-dated pricing, unit-aware financial calculations, late data, and replay-safe ingestion. |
| Submitted `dag.sql` | **2–4 years** of SQL / analytics-engineering implementation maturity | Demonstrates staged DAG design, normalization, incremental history, key handling, window functions, price change points, replacement decisions, and order-grain aggregation. Several source-specific formats and whole-day correction semantics are represented more narrowly than the README describes. |
| Reference `gold_submit.sql` | **4–7 years** of specialized data-engineering / analytics-engineering skill equivalence | Demonstrates broader event classification, identifier normalization, partition-replacement thinking, price history, and state ranking across event types. The estimate reflects breadth of concepts, not SQL length. |

The rubric considers **scope covered, modeling and temporal reasoning, financial correctness, edge-case coverage, replay/idempotency strategy, late-data handling, determinism, and maintainability**. It does not convert lines of code into years. A concise solution built on reliable shared parsers and well-defined source contracts can demonstrate more engineering maturity than a longer query full of ad hoc expressions.

Keep these ideas separate:

1. **Challenge difficulty** describes the complexity of the requirements.
2. **Experience-equivalent range** describes the breadth of practical skills demonstrated by an approach.
3. **Actual employment years or hiring level** require much broader evidence than one challenge.
