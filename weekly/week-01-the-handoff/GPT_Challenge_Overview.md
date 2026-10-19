# Week 1: The Handoff — Challenge Overview

## 1. Challenge at a Glance
Transform a legacy CRM's inconsistent nightly export into a clean customer table for finance.
- **Input:** one customer-like JSON record per line, with malformed and inconsistent variants.
- **Output grain:** one row per valid customer.
- **Fields:** `customer_id`, `email`, `signup_at`, `plan`, `seats`, `mrr_usd`.
- **Core techniques:** parsing, schema normalization, type conversion, timestamp handling, validation, and deduplication.

## 2. Domain Knowledge
A CRM stores customer accounts and subscription details. The customer ID is the entity key; plan is the subscription tier; seats represent licenses; MRR is monthly recurring revenue. Legacy rewrites often leave several historical schemas in one export. A timestamp can be syntactically numeric yet semantically wrong if milliseconds are mistaken for seconds.

## 3. Business Rules and Output Contract
Resolve supported field aliases and nested locations; normalize customer IDs, emails, plans, timestamps, seats, and monetary values; convert null sentinels into actual nulls; exclude export bookkeeping fields; and define a deterministic duplicate policy. Unknown plans must not be guessed into a supported plan. A malformed optional field should not necessarily invalidate every other field. Output must retain the required columns and types.

## 4. Difficulty Assessment
**Beginner-to-intermediate ETL, with intermediate parsing edge cases.** Individual conversions are familiar, but historical schema drift, localized keys, malformed JSON, ambiguous timestamps, and replayed records require separate explicit rules. Parsing asks whether a value can be converted; validation asks whether it is meaningful under the contract.

## 5. Estimated Experience Equivalence

These estimates describe the challenge's engineering demands and the patterns visible in the implementations. They are heuristic learning references, not validated hiring benchmarks or a judgment of the author's overall professional seniority.

### 5.1. Overall Comparison

| Evidence Source | Lens | Level | Estimated YoE | Short Rationale |
|---|---|---|---|---|
| Problem statement (README.md) | Challenge difficulty | Junior to Mid-level | Approximately 1–3 years of relevant data-processing experience | One row per customer sounds simple, but the feed combines schema drift, nested/localized keys, malformed/truncated JSON, timestamp variants, formatted numbers, aliases, and duplicate delivery. |
| Your submission (handler.py) | Demonstrated implementation | Junior-level patterns with some intermediate concepts | Approximately 0–1 year equivalent for the patterns demonstrated | Validates customer IDs, converts common types, normalizes a few values, and stores rows by ID. It mainly reads top-level fields, treats numeric epochs as seconds, uses broad exception handling, and returns rows from both process and finalize. |
| Reference solution (gold_submit.py) | Solution sophistication | Mid-level to Senior-level problem-solving patterns | Approximately 3–4 years of relevant experience | Includes tolerant JSON recovery, alias/nested-field resolution, email extraction, multiple timestamp forms, null-sentinel handling, and more explicit normalization and validation. |

YoE describes rough pattern-equivalence, not a claim that a person needs exactly these years to solve the task.

### 5.2. Skill-by-Skill Comparison

| Skill Group | Problem Target | Submission Evidence | Reference Evidence |
|---|---|---|---|
| Python and JSON parsing | Junior–Mid | Basic JSON parsing; malformed records are caught by a broad exception handler | Multi-path recovery for noisy JSON records |
| Schema drift and nested fields | Mid | Primarily reads expected top-level field names | Alias resolution and nested/flattened field recovery |
| Timestamp normalization | Junior–Mid | ISO parsing and numeric epoch conversion; numeric units are not visibly distinguished | Multiple timestamp formats and epoch conventions |
| Numeric and financial parsing | Junior–Mid | Basic integer/float conversion and float rounding for MRR | Decimal-based handling and defensive numeric parsing |
| Domain validation | Junior–Mid | Customer ID format and allowed plans are checked | Broader field cleaning and contract-aware normalization |
| Identity and deduplication | Mid | State is keyed by customer ID, but rows are returned from process as well as finalize | Accumulates state and emits the final customer set |
| Malformed/truncated input | Mid | Invalid JSON is dropped rather than recovered | Attempts recovery from noisy JSON; truly truncated content remains inherently limited |

### 5.3. Evidence Behind the Estimate

- The README describes three CRM rewrites, localized keys, fields moving between nested and flat structures, mixed timestamps, and human-formatted numeric values. This exceeds simple JSON conversion.
- The submission shows useful foundations: customer-ID validation, plan allow-listing, type conversion, and keyed state.
- Full alias/nesting recovery is not visible in the submission. Returning rows from process and then accumulated rows from finalize also risks duplicate emission.
- The reference demonstrates broader defensive parsing. Complexity is evidence of one approach, not proof that every heuristic is universally correct.

### 5.4. What Each Level Looks Like Here

| Level | Expected Demonstration |
|---|---|
| Beginner / Entry-level | Parses valid JSON and converts fields with known formats. |
| Junior Data Engineer | Adds validation, null cleanup, type conversion, and simple keyed state. |
| Mid-level Data Engineer | Designs alias/nesting resolution, robust timestamp and numeric parsing, deterministic duplicate handling, and clear process/finalize semantics. |
| Senior-level problem-solving | Makes recovery policies explicit, separates recoverable corruption from unrecoverable truncation, and balances data quality, observability, correctness, and runtime cost. |

### 5.5. Assumptions and Limitations

1. README.md defines the intended difficulty; handler.py shows the submitted patterns; gold_submit.py is one reference example.
2. “Not demonstrated” does not prove the author lacks a skill.
3. YoE ranges are illustrative, not empirical; experience varies by project scope, mentoring, and domain exposure.
4. The reference is not the only valid design, and parsing heuristics must follow the exact contract.
5. This section assesses the challenge and code evidence, not the author's overall career level.

**Overall conclusion:** Week 1 is a Junior-to-Mid-level data-processing challenge. The submission demonstrates basic ETL foundations; the largest learning opportunities are schema drift, tolerant parsing, timestamp-unit detection, and emitting one final row per customer.

## 6. Core Engineering Patterns
- Separate parsing, normalization, validation, and output.
- Resolve aliases with explicit precedence.
- Canonicalize IDs and values before deduplication.
- Use decimal arithmetic when monetary precision matters.
- Make repeated delivery idempotent.
- Preserve valid optional fields when other fields are malformed.

## 7. Common Traps
- Assuming JSON key order matters.
- Treating every epoch value as seconds.
- Mapping unknown plans to a default.
- Treating `"null"`, `"N/A"`, or `"-"` as real values.
- Using broad exception handling that hides programming defects.
- Emitting one row per delivery instead of per customer.

## 8. Independent Examples
**Timestamp units:** `1780000000` may be seconds while `1780000000000` may be milliseconds; classify according to source rules before converting to UTC.

**Missing email:** trim `" N/A "` and map it to null before validation.

**Duplicate customer:** when two deliveries share a canonical ID, apply a documented winner rule instead of appending both.

## 9. Technical Topics to Study
1. JSON parsing, malformed-input recovery, and nested dictionaries.
2. Schema evolution, field aliases, and canonical data models.
3. UTC, timezone offsets, and epoch seconds versus milliseconds.
4. Decimal arithmetic, data quality, and idempotency.

## 10. Suggested Learning Plan
1. Parse valid JSON lines.
2. Normalize whitespace, casing, and null sentinels.
3. Add alias and nested-field resolution.
4. Test timestamp and numeric parsers independently.
5. Validate IDs, plans, and emails.
6. Define duplicate precedence and test mixed-quality records.

## 11. Validation Checklist
- [ ] Does parsing work regardless of JSON key order?
- [ ] Are aliases and nested locations supported?
- [ ] Are epoch units and time zones interpreted explicitly?
- [ ] Are missing sentinels normalized?
- [ ] Are unknown contract values handled without guessing?
- [ ] Can a bad optional field coexist with valid fields?
- [ ] Does repeated delivery yield one row per customer?
- [ ] Does output match the required schema?

## 12. Evidence and Assumptions
The README documents the legacy CRM scenario, output fields, and heterogeneous records. `handler.py` and `gold_submit.py` were reviewed to understand the interface and possible implementation approaches. Experience ranges are approximate educational estimates. Ambiguous formats must follow source-specific challenge rules.
