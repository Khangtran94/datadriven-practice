---
week: 1
folder: week-01-the-handoff
title: The Handoff
format: python
domain: SaaS / Customer master data - CRM migration
difficulty: 3
yoe_problem: 2-4
yoe_you: 1-3
yoe_gold: 4-6
confidence_you: medium
score: 0.5159
rank: 8/11
analysis: yes
---

# Week 1: The Handoff - Problem overview

Python handler · score 0.5159, rank #8 of 11 `[measured]` · analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)

## 1. The problem in one paragraph

A company is retiring a CRM it has used since 2019. The only feed left is a nightly export: 1 JSON line per customer, written by whichever of 3 generations of exporter touched it last. Finance needs **1 clean row per customer** (`customer_id`, `email`, `signup_at`, `plan`, `seats`, `mrr_usd`) to close the fiscal year. You write a `Handler` with `process(raw)` (called once per line) and `finalize()`, and the stream is about 951,000 records. The difficulty is not the logic of any one field: it is that every field arrives in many shapes, and the same customer can arrive more than once.

## 2. Domain and real-world context

**SaaS / customer master data (system migration).** When a company replaces a CRM, the old system's export becomes the source of truth for who the customers are, what plan they are on, and how much recurring revenue (MRR) they bring. If a customer is dropped, duplicated or has the wrong plan, finance's revenue numbers are wrong. In real life this is the "extract and clean" step of nearly every data migration, and the data is always written by several generations of software that never agreed on a format.

## 3. Difficulty: 3/5

| Measured | Value |
|---|---|
| Data conditions listed in the README | 15 `[measured]` |
| Output columns | 6 `[measured]` |
| Records in the stream | 951,089 `[measured]` |
| Interface | `process` per line, `finalize` at the end `[measured]` |
| Cross-record rule | one row per customer even when a record is resent `[measured]` |
| Hard limits | none stated; "work per record" is a scored metric `[measured]` |

Why 3: 15 conditions fall in the 10-20 band, but almost all are independent per-field cleanings, so it is the easiest of the five weeks. The only cross-record rule is identity: at-least-once delivery means the reader must settle duplicates. It would be one level harder with a memory limit or a rule that a later record corrects an earlier one.

## 4. Problems the data throws at you

1. **Damaged structure.** Key order is arbitrary (30%), JSON is concatenated by string (6%), lines are cut off mid-write (0.8%), fields moved in and out of sub-objects over 3 rewrites (10%), and some keys are localized (5%). Hard because a strict `json.loads` drops the whole line, and position-based reading reads the wrong field.
2. **The same value in many types and formats.** Epoch seconds vs milliseconds (8%), mixed date formats (8%), numbers written for humans such as `1,200.50` or `€12,5` (5%), plan names from three eras (6%). Hard because every variant parses as something plausible.
3. **Fake nothing.** Nulls spelled as strings (30%), padding and casing (12%), emails with display names or `mailto:` (4%). Hard because `"N/A"` is a valid string and does not look broken.
4. **Noise and contract.** Export bookkeeping fields (10%) that describe the run, not the customer; plans outside the contract (1%) that must become null.
5. **Resent records.** Retries and overlapping windows resend records (4%). Hard because the reader decides identity.

## 5. Data-engineering concepts to know

| Concept | What it means in this problem | Search keywords |
|---|---|---|
| Tolerant parsing | Recover what you can from broken JSON instead of dropping the line | `json repair`, `partial parse`, `JSONDecodeError` |
| Schema normalization | Map aliases and nested paths to one canonical record | `key aliasing`, `flatten nested json`, `canonical schema` |
| Type coercion | Turn strings with separators, symbols and decimal commas into numbers | `locale number parsing`, `Decimal`, `type casting` |
| Timestamp normalization | Epoch s/ms, naive and zoned strings to one UTC ISO 8601 form | `epoch seconds vs milliseconds`, `ISO 8601`, `tz-aware datetime` |
| Null semantics | Treat markers like `"null"`, `"N/A"`, `""` as missing | `sentinel values`, `missing data`, `null handling` |
| Deduplication | One output row per business key | `idempotent processing`, `at-least-once delivery`, `dedupe by key` |
| Stream handler pattern | Emit per record or at `finalize`, and know which one the grader reads | `streaming vs batch`, `process/finalize`, `stateful processing` |
| Contract validation | Reject values outside an allowed set instead of guessing | `enum validation`, `data contract` |
| Money precision | Round with `Decimal`, not float | `Decimal ROUND_HALF_EVEN`, `floating point money` |

A short example for the seconds-vs-milliseconds trap (a 10-digit number is seconds, a 13-digit one is milliseconds):
```python
ts = ts / 1000 if ts > 1e11 else ts
```

## 6. Estimated years of experience (YoE)

| | Range | Confidence | Deciding evidence |
|---|---|---|---|
| What the problem needs | **2-4 years** | medium | defensive parsing and normalization across 15 independent cases, plus one identity rule |
| Your code (`handler.py`) | **1-3 years** | medium | 69 lines with real guard clauses and per-field cleaning (L11-L52), a strict ID check (L16), but only one spelling of each key and a bare `except` that returns `[]` (L65) |
| Gold code (`gold_submit.py`) | **4-6 years** | medium | alias lists per field (L231-L255), tolerant JSON parser that recovers a `{...}` span (L28-L63), several date patterns and `Decimal` rounding (L1-L22), stateless `Handler` (L258-L270) |

- The gap is breadth of defence, not logic: the gold expects many spellings and shapes of each field; your handler handles the clean case well and one or two variants.
- Caveat: these numbers describe the level of the problem and the code, not a person. The gold is a top result and may have been refined against feedback.

## 7. Common traps

- **Relying on key order or one spelling of a key.** Sign: `record.get('customer_id')` is the only lookup.
- **Letting one bad line kill the parse.** Sign: `json.loads` in a `try` that returns nothing on failure.
- **Treating `"null"`, `"N/A"`, `""` as values.** Sign: a column full of the word `None`.
- **Mixing seconds and milliseconds.** Sign: signup dates in 1970 or in the year 50,000.
- **Naive datetimes.** Sign: output times without a zone, shifted by hours.
- **Floats for money.** Sign: `0.1 + 0.2` style cents drift.
- **Bare `except`.** Sign: a typo hides as "dropped record" and the score is silently lower.
- **Emitting the same key twice** (once as you go, once at the end). Sign: more output rows than distinct customers.

## 8. Mindset difference (you vs gold)

Your handler is written for the record you expect, with guards for the failures you can name. The gold is written for the record you do *not* expect: it lists many aliases per field, tries several parses in order and only then gives up. Bugs, before/after code and how to verify are in [Claude_Analysis.md](./Claude_Analysis.md).

## 9. Matching interview questions

1. **(mid)** A JSON line is cut off mid-write. What do you do with it? *Hint: keep what was complete before the cut, or skip safely; never crash the stream.*
2. **(mid)** How do you tell epoch seconds from milliseconds without a unit? *Hint: by magnitude; 1e9-1e10 is seconds, 1e12-1e13 is milliseconds.*
3. **(mid)** Why use `Decimal` for MRR? *Hint: exact decimal arithmetic and explicit rounding, no binary float drift.*
4. **(senior)** The source is at-least-once. How do you guarantee 1 row per key, and what does it cost in memory? *Hint: key-indexed state; the cost grows with the number of keys, so decide what to keep.*
5. **(mid)** A value is outside the allowed list of plans. Keep, map or null? *Hint: follow the contract; unknowns become null so they are visible, not guessed.*

## 10. Learning path

**Order of study:** (1) tolerant JSON parsing → (2) key aliasing and flattening → (3) timestamp normalization → (4) dedupe with a bounded state.

**Exercise 1 - Alias lookup (30 min).** Write `first(rec, names)` that returns the first non-blank value among `["customer_id", "customerId", "id"]`. *Self-check:* records using any one spelling give the same row, and a blank string falls through to the next name.

**Exercise 2 - Timestamp normalizer (45 min).** Accept epoch seconds, epoch milliseconds, ISO with `Z`, ISO with `+05:30`, and a date with no zone, and output `YYYY-MM-DDTHH:MM:SSZ`. *Self-check:* the same instant written 5 ways gives the same output string.

**Exercise 3 - One row per key (45 min).** Feed 10 lines with 4 repeated customers and decide which version wins. *Self-check:* the output has exactly 6 distinct keys, and you can state your tie-break rule in one sentence.

## 11. Links

- Analysis of your submission: [Claude_Analysis.md](./Claude_Analysis.md)
- Challenge on the platform: [The Gauntlet - Week 1](https://datadriven.io/community/week-1)
