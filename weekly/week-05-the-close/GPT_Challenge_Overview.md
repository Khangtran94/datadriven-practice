# Week 5: The Close — Challenge Overview

## 1. Challenge at a Glance
Build a SQL DAG for a card-payments company's historical book close. Three nightly raw copies have limited retention, so the pipeline must reconstruct payment facts, settlement movements, merchant attributes, and FX conversion despite late data and restatements.
- **Input:** raw payment, merchant, and FX-rate copies with batch/load metadata.
- **Output grain:** one row per payment.
- **Fields:** `payment_id`, `status`, `amount_usd`, `settled_usd`, `settled_in_period_usd`, `captured_at`, `order_ref`, `merchant_country`.
- **Core techniques:** SQL modeling, temporal reconstruction, incremental DAG design, financial aggregation, and as-of joins.

## 2. Domain Knowledge
Payment state changes over time. Authorization and capture describe payment states; settlement movements record money moving across nights and may include negative adjustments or reversals. Merchant country and test/live attributes can change. FX rates are currency/date-specific and may be revised or arrive late. Currency minor units vary; not every currency has two decimal places. Batch date, business-effective date, and load time are different concepts.

## 3. Business Rules and Output Contract
Normalize IDs without losing leading zeros, parse null sentinels and metadata safely, and normalize timestamps. Separate business time from landing time. Deduplicate within/across batches with deterministic keys. Reconstruct payment fields across partial updates rather than letting a sparse newest row erase earlier valid values. Aggregate settlement movements exactly once, including reversals. Replace restated day contributions rather than adding them again. Normalize gateway status vocabularies and currency scales. Select one valid FX rate according to the required prior-date rule. Resolve merchant attributes as of the payment date. Recompute affected payments when late payment, merchant, or FX data arrives. Respect the required schedule, dependencies, SQL dialect, and date window.

## 4. Difficulty Assessment
**Advanced SQL/data engineering.** Correctness depends on grain, temporal history, financial precision, restatement semantics, and incremental recovery. A query can return one row per payment and still be wrong if it loses older fields, double-counts settlements, joins multiple FX rates, or uses current merchant attributes instead of historical ones.

## 5. Estimated Experience Equivalence
These estimates are heuristic learning references, not validated hiring benchmarks or an assessment of the user's overall competence.

| Skill | Approximate experience equivalent | Rationale |
|---|---|---|
| SQL transformations and modeling | 2–4 years | CTEs, window functions, aggregation, explicit grain |
| Temporal history reconstruction | 3–5 years | Partial updates, late arrivals, restatements, as-of attributes |
| Financial data correctness | 3–5 years | Settlement movements, reversals, currency precision, FX |
| Incremental DAG and recovery design | 3–5 years | Scheduling, idempotency, backfills, recomputation |

**Challenge-level estimate: roughly 3–5 years of relevant data engineering experience**, assuming competent SQL fundamentals. The README establishes scope; `dag.sql` shows the submitted DAG shape; `gold_submit.sql` demonstrates one detailed approach. These sources estimate task complexity, not the author's actual years of experience. The reference is not the only acceptable architecture.

## 6. Core Engineering Patterns
- Declare the grain of every intermediate relation.
- Separate business-effective date, batch date, and load time.
- Reconstruct fields independently when updates are partial.
- Make incremental processing idempotent and replay-safe.
- Aggregate settlement events at movement grain, including reversals.
- Use as-of joins for FX and merchant attributes.
- Recompute affected keys when late data arrives.
- Validate DAG dependencies and intermediate contracts.

## 7. Common Traps
- Assuming the newest batch always has the newest business state.
- Taking the latest row wholesale when it omits older fields.
- Adding a restated batch instead of replacing that day's contribution.
- Summing a final state instead of individual settlement movements.
- Dividing every currency by 100 or mixing major and minor units.
- Joining only on exact FX date when a prior rate is required.
- Using latest merchant country instead of the country at payment time.
- Failing to revisit results affected by late data.
- Assuming a JSON function safely accepts truncated metadata.

## 8. Independent Examples
**Partial update:** an earlier row has amount and currency; a later dispute row has only status. If blank means “not supplied by this update,” preserve the earlier valid amount and currency.

**Settlement:** movements of +70, +30, and -10 total 90 if each distinct movement is counted exactly once.

**FX:** if Sunday has no rate and the contract requires the latest rate on or before the payment date, select the eligible prior rate.

**Restatement:** a corrected copy replaces/recomputes that day's contribution; it must not be added on top of the earlier version.

## 9. Technical Topics to Study
1. SQL CTEs, window functions, aggregation, and query grain.
2. Temporal history, partial updates, slowly changing dimensions, and as-of joins.
3. Incremental models, DAG dependencies, late arrivals, backfills, and idempotency.
4. Settlement accounting, reversals, currency minor units, FX selection, and reconciliation.

## 10. Suggested Learning Plan
1. Write down the grain of every raw and intermediate relation.
2. Normalize IDs, nulls, timestamps, statuses, and metadata into staging CTEs.
3. Build payment, merchant, and FX history models separately.
4. Implement deterministic deduplication and field-level history reconstruction.
5. Test settlement movements with hand-calculated examples.
6. Add temporal joins for FX and merchant attributes.
7. Define which payments are affected by late/restated batches.
8. Design DAG scheduling, dependencies, and incremental recomputation.
9. Validate monetary totals, row grain, and replay safety.

## 11. Validation Checklist
- [ ] Is each model's grain explicit and correct?
- [ ] Are business date, batch date, and load time distinct?
- [ ] Are IDs normalized without losing leading zeros?
- [ ] Are partial updates merged according to field-level semantics?
- [ ] Are duplicates and restated batches handled without double counting?
- [ ] Are settlement movements and reversals counted exactly once?
- [ ] Is currency precision correct?
- [ ] Is one deterministic FX rate selected per required currency/date?
- [ ] Are merchant attributes resolved as of payment date?
- [ ] Can late data repair previous results?
- [ ] Can tasks be rerun safely?
- [ ] Does the DAG meet the required schedule, SQL dialect, and output contract?

## 12. Evidence and Assumptions
The README documents the book-close scenario, three raw sources, bounded period, output schema, and risks around late copies, restatements, settlement, currencies, FX, and merchant history. `dag.sql` and `gold_submit.sql` were reviewed for submitted structure and one reference approach. Estimates are heuristic. Exact schedule and incremental semantics must follow the challenge runtime; the reference is not a universal production template.
