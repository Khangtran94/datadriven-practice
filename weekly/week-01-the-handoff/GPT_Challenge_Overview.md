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
Heuristic learning estimate, not a validated hiring benchmark or a measurement of an individual's overall ability.

| Skill | Approximate experience equivalent | Rationale |
|---|---|---|
| Python and JSON | 0–2 years | Defensive parsing and field access |
| Schema normalization | 1–3 years | Aliases, nesting, and missing-value sentinels |
| Timestamp and financial parsing | 1–3 years | Epoch units, time zones, decimal precision |
| Reliable ingestion | 1–3 years | Stable identity and replay handling |

**Challenge-level estimate: roughly 1–3 years of practical data-processing experience.** The README defines scope; `handler.py` shows the interface; `gold_submit.py` illustrates one possible depth of normalization. These sources estimate task demands, not the user's skill level. The reference is not the only valid design.

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
