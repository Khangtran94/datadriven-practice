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

This section estimates the Week 5 challenge and compares it with patterns visible in dag.sql and gold_submit.sql. These are heuristic learning estimates, not validated hiring benchmarks or a judgment of the author's overall professional seniority.

### 5.1. Overall Comparison

| Evidence Source | Lens | Level | Estimated YoE | Short Rationale |
|---|---|---|---|---|
| Problem statement (README.md) | Challenge difficulty | Mid-level to Senior-level problem-solving | Approximately 3–5+ years of relevant data-engineering experience | Combines incremental history, late data, partial updates, settlement movements and reversals, currency minor units, FX selection, restatements, temporal merchant attributes, and safe recomputation. |
| Your submission (dag.sql) | Demonstrated implementation | Junior-level SQL/DAG patterns | Approximately 0–1 year equivalent for the patterns demonstrated | Declares task dependencies and incremental materialization, but history tasks use SELECT * without visible normalization or merge-key logic. The final fact query does not demonstrate settlement aggregation, FX conversion, or an as-of merchant lookup. |
| Reference solution (gold_submit.sql) | Solution sophistication | Senior-level problem-solving patterns | Approximately 4–6+ years of relevant experience | Uses incremental merge configuration with row keys, null/value normalization, timestamp handling, and more extensive transformations for reconstructing payment, FX, and merchant history. Each business rule still needs validation against the README. |

The ranges describe rough experience-equivalent patterns, not the years required for every engineer to solve the challenge.

### 5.2. Skill-by-Skill Comparison

| Skill Group | Problem Target | Submission Evidence | Reference Evidence |
|---|---|---|---|
| SQL fundamentals and DAG structure | Junior–Mid | Defines named tasks, dependencies, and SELECT projections | Uses multiple CTE-based transformations and explicit incremental configuration |
| Stable keys and deduplication | Mid–Senior | No explicit merge key or deduplication logic is visible in the history tasks | Defines row-key concepts and merge unique keys |
| Incremental history and replay safety | Mid–Senior | Incremental materialization is declared, but merge behavior and replay-safe state are not demonstrated | Explicit merge configuration and normalized history processing |
| Partial updates and temporal reconstruction | Senior-level problem-solving | Final fact query does not reconstruct field-level history | More extensive history transformations; field-level winner semantics still require verification |
| Settlement aggregation and reversals | Mid–Senior | Selects settled directly rather than visibly aggregating movements | Must be checked against settlement and reversal rules in the complete reference |
| FX and currency minor units | Mid–Senior | No visible FX join or currency-scale conversion in the final fact query | More extensive FX/history transformations; correctness depends on rate selection and scale rules |
| Merchant as-of attributes | Mid–Senior | merchant_country is hard-coded as NULL | Merchant-history handling patterns; temporal correctness must be verified |
| Dirty JSON and timestamps | Mid–Senior | Direct JSON extraction without visible malformed-metadata protection | More normalization and timestamp processing; malformed-input behavior depends on the SQL engine |

### 5.3. Evidence Behind the Estimate

- The README says raw tables retain only recent copies, so the pipeline must preserve history and account for data arriving after a run.
- Payment rows can be partial updates, while settlement movements span multiple nights and include reversals. Taking the newest row or a single settled value is not equivalent to reconciling movements.
- FX rates can be missing, revised, or late; merchant attributes can change or disappear. These require temporal selection and a policy for recomputing affected payments.
- The submitted DAG establishes a basic task graph, but the final fact query does not visibly implement several central financial and temporal requirements.
- The reference demonstrates more advanced incremental and normalization patterns. It should still be checked against the reporting window and business rules; sophistication alone does not prove correctness.

### 5.4. What Each Level Looks Like Here

| Level | Expected Demonstration |
|---|---|
| Beginner / Entry-level | Writes basic SELECT statements and understands simple task dependencies. |
| Junior Data Engineer | Builds staging transformations, normalizes common nulls/types, and defines output columns. |
| Mid-level Data Engineer | Implements stable keys, deduplication, incremental merge behavior, partial-update reconstruction, temporal joins, and financial validation. |
| Senior-level problem-solving | Designs replay-safe historical recovery for late/restated data, handles settlement reversals and currency-specific precision, and recomputes affected outputs deterministically. |

### 5.5. Assumptions and Limitations

1. README.md is the source for intended requirements; dag.sql is the submission; gold_submit.sql is one reference approach.
2. “Not demonstrated” means the SQL does not show the logic; it does not establish the author's overall capability.
3. SQL dialect and runtime behavior matter, especially for JSON parsing, incremental materialization, and date/time conversion.
4. Date assumptions in the reference must be reconciled with the README's stated period before being accepted as correct.
5. Claims that a query crashes require reproducible runtime evidence; static inspection supports only a potential-failure statement.
6. YoE ranges are illustrative, not empirical hiring thresholds.

**Overall conclusion:** Week 5 targets Mid-level Data Engineering competence with several Senior-level problem-solving requirements. The current submission demonstrates basic SQL and DAG structure; the biggest visible gaps are incremental history resolution, settlement reconciliation, FX conversion, temporal merchant lookup, and robust metadata handling. This is a learning roadmap, not a verdict on the author's career seniority.

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
