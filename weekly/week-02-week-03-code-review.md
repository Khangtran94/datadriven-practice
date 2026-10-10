# Week 2 and Week 3 — Handler vs. Top-1 Review

This document compares my `handler.py` with the top-1 `gold_submit.py` for Week 2 and Week 3. The central lesson is that parsing records correctly is only part of the task: the handler must also reconcile records by business key and emit the final table at the correct lifecycle stage.

## Files reviewed

- [Week 2: my handler](https://github.com/Khangtran94/datadriven-practice/blob/main/weekly/week-02-the-manifest/handler.py)
- [Week 2: top-1 submission](https://github.com/Khangtran94/datadriven-practice/blob/main/weekly/week-02-the-manifest/gold_submit.py)
- [Week 3: my handler](https://github.com/Khangtran94/datadriven-practice/blob/main/weekly/week-03-the-register/handler.py)
- [Week 3: top-1 submission](https://github.com/Khangtran94/datadriven-practice/blob/main/weekly/week-03-the-register/gold_submit.py)

## Executive summary

| Topic | My code | Top-1 code | Main lesson |
|---|---|---|---|
| Output lifecycle | Returns rows from `process()`; `finalize()` returns `[]` | Retains state and emits reconciled rows during finalization | State changes cannot retract rows already returned |
| Week 2 business keys | Holds the latest row by `(title_id, rendition)` | Reconciles held candidates and handles job/context/pending records | Model both output identity and record relationships |
| Equal-time conflicts | No robust field-by-field tie merge | Merges compatible fields and treats unresolved conflicts carefully | Define deterministic tie-breaking rules |
| Week 3 quality precedence | Rejects same-rank candidates as well as lower-ranked ones | Higher rank wins; equal rank can merge available fields | Same-rank records may contain useful missing fields |
| Week 3 register deltas | Calculates usage as records arrive | Sorts retained intervals and calculates deltas in `finalize()` | Time-dependent calculations must account for late arrivals |

**Overall:** the largest gap is not code length. It is the separation between parsing, reconciliation, derived calculations, and final output.

# Week 2 — The Manifest

## My implementation

My handler extracts and normalizes a JSON payload, checks quality, cleans the row, then keys state by `(title_id, rendition)`. It replaces the stored candidate when a newer `packaged_at` is observed and returns that row immediately.

The state dictionary only represents the latest candidate *known so far*. If an older row was already returned and a newer version arrives later, updating the dictionary does not remove the previously emitted row. Since `finalize()` returns an empty list, it does not emit a final reconciled table.

## Top-1 implementation

The top-1 submission separates two types of state:

- **Held results:** one candidate per business key, reconciled using timestamps and field-level information.
- **Job/context state:** job metadata, incomplete records, pending outputs, and closure information.

This lets it handle records that are not complete on their own but can be interpreted with context from other events. Finalization flushes eligible pending outputs and returns the held final rows.

## Week 2 improvements

1. Parse raw input into normalized candidate records.
2. Resolve job context and pending/incomplete records according to the specification.
3. Reconcile candidates in state without emitting every intermediate winner.
4. Define same-timestamp rules, including missing fields and conflicting values.
5. In `finalize()`, return one reconciled row per output business key.

Useful invariant: **at the end of processing, there is at most one final candidate per output key.**

# Week 3 — The Register

## My implementation

My handler has useful state separation:

- `reads`: readings grouped by meter and bucket;
- `regs`: register values used for usage inference;
- `sent`: signatures of rows already emitted.

It deduplicates by quality rank, merges readings, and infers missing usage from a prior register reading. The risk is that the previous reading known at processing time may not be the true chronological predecessor. A late-arriving interval can change a later delta, but cannot revise a row already returned.

Also, `_dedup()` rejects candidates whose rank is less than **or equal to** the existing rank. A same-rank record that fills a null field or supplies a correction may therefore be discarded.

## Top-1 implementation

The top-1 submission retains one candidate per meter and interval. It applies quality precedence and merges non-null values at equal rank. In `finalize()`, it groups by meter, sorts intervals chronologically, derives missing usage from eligible register deltas, and builds the output rows.

## Example: late-arriving readings

Suppose the records arrive in this order:

| Arrival | Interval | Register |
|---:|---|---:|
| 1 | 11:00 | 150 kWh |
| 2 | 10:30 | 140 kWh |
| 3 | 11:30 | 165 kWh |

Once sorted chronologically, inferred usage is:

| Interval | Register | Inferred usage |
|---|---:|---:|
| 10:30 | 140 kWh | Unknown without an earlier reading |
| 11:00 | 150 kWh | 10 kWh |
| 11:30 | 165 kWh | 15 kWh |

If 11:00 is emitted before 10:30 arrives, the original output may be stale. Collecting and reconciling first, then sorting and deriving deltas, makes the calculation less dependent on arrival order.

## Week 3 improvements

1. Normalize the business key `(meter_id, interval_end)`.
2. Reconcile duplicate candidates using the documented quality and conflict rules.
3. Group final readings by meter and sort by UTC interval end.
4. Derive missing usage only after reconciliation, enforcing the specified interval-gap and non-negative-delta rules.
5. Serialize values exactly as required, including fixed three-decimal numeric strings.
6. Emit the final rows once.

# What `process()` and `finalize()` mean

- `process(raw)` handles one input and returns zero or more rows.
- `finalize()` performs work that needs the end of input, then returns any remaining/final rows.

Returning `[]` from `finalize()` means it contributes no additional rows; it does **not** erase rows previously returned by `process()`. Confirm the runner contract before changing the lifecycle: check whether it calls `finalize()` and collects its return value.

A simple local diagnostic:

```python
handler = Handler()

for raw in sample_inputs:
    print("process:", handler.process(raw))

print("finalize:", handler.finalize())
```

For a finite batch challenge, a common design is to buffer and reconcile during `process()`, then emit the final table from `finalize()`. For a true streaming contract, use the runner's defined update, retraction, or watermark semantics instead of assuming state mutation can change prior output.

# Prioritized action plan

## 1. Verify the runner contract

Confirm whether the runner calls `finalize()`, collects its returned rows, and immediately collects each `process()` result. Correct internal state is not enough if output timing is wrong.

## 2. Separate the pipeline stages

Use distinct responsibilities:

`parse → normalize → reconcile → derive → serialize → emit`

Preserve existing parsing helpers that already work. Focus the redesign on reconciliation and output lifecycle.

## 3. Make tie and precedence rules explicit

For each business key, define which timestamp/rank wins, how equal-ranked candidates merge, whether null fields can be filled, and how genuine conflicts are resolved. Do not rely on incidental dictionary insertion order unless guaranteed by the specification.

## 4. Test invariants and input order

Add tests for:
- duplicate keys with older records arriving later;
- same-key candidates with complementary fields;
- conflicting same-time values;
- malformed JSON and unexpected field types;
- Week 2 records that depend on job context;
- Week 3 intervals arriving out of chronological order;
- missing usage with a valid 30-minute predecessor;
- gaps, invalid predecessors, and negative register deltas.

Where the specification says arrival order should not matter, run the same records in different permutations and compare the final output.

# Final assessment

- **Week 2:** the biggest gap is job/context reconciliation and producing one final row per business key rather than emitting candidate versions as they arrive.
- **Week 3:** the biggest gap is temporal correctness under late arrivals. The existing helper functions are a useful foundation, but register-derived usage should be calculated from the reconciled chronological series.
- **Both weeks:** treat the output table as a finalized data product, not as a side effect of each input record.

The top-1 pattern worth adopting is: **collect → normalize → reconcile → derive → serialize → emit**.
