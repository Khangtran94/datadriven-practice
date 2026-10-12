# Week 4 — The Interface: handler.py vs gold_submit.py

## Result at a glance

- **Submitted score:** 0.0000
- **Rank:** #6 of 6
- **Rows recovered by the submitted run:** 0 of 749,978
- **Work per record:** 1.8× median
- **Run:** stopped at record 1,000,000
- **Statements:** 355
- **Scored:** 2026-10-11

## Why the score was 0: memory exhaustion

**The primary reason for the zero score was that the run exceeded the 512 MB memory limit before `finalize()` returned any rows.** The zero score therefore does not, by itself, show that the parser's output logic was entirely wrong.

The handler retained growing state across the stream:

- `self.groups` stores candidate dictionaries for keys until final reconciliation.
- `self.seen` stores message fingerprints used for deduplication.
- `finalize()` builds the output only after the stream has been processed.

Across one million records, these structures accumulated too much memory. The full-stream projection was approximately **1,238 MB against a 512 MB limit**. The sample's reported peak of **19 MB / 512 MB** came from only 300 lines, mostly reflecting Python's baseline memory usage; it was not representative of the complete stream. The run processed the millionth record but was stopped before the final output was returned, so the evaluator had no completed rows to score. The reported failure reason subsequently changed from timeout to memory.

### Why competitive per-record cost did not save the run

| Metric | Your run | Winning run |
|---|---:|---:|
| Work per record | 1.77× median | 1.71× median |
| Full stream | Read 1,000,000 records in under 2 minutes | Completed |
| Memory | Projected at about 1,238 MB | Stayed within the limit |

Work per record measures processing effort, not retained state. A handler can do a similar amount of work per record and still fail if it keeps too much data in memory. The winner's per-record cost was close to yours, but its lower memory footprint allowed it to finish.

When your output was scored offline against the same stream, it achieved **0.7883**, which would have ranked second in that offline evaluation. This is evidence that the parsing logic has real potential. It does not mean every edge case is correct or that the submitted implementation was production-ready: the actual run still must finish within the resource limits.

### Memory fixes to prioritize

1. **Keep only the current winning candidate per key** when the reconciliation rules make incremental replacement safe.
2. **Use compact tuples or lightweight records** instead of allocating a full dictionary for every candidate.
3. **Reduce or remove message fingerprints** if equivalent deduplication can be performed with less memory without changing required behavior.
4. **Measure memory at realistic scale.** A 300-line sample cannot reliably predict a one-million-record run.
5. **Preserve revision semantics.** Before discarding older candidates, test corrected, withdrawn, preliminary, duplicate, and out-of-order messages to ensure the final winner remains correct.

Keeping only the latest winner is not automatically safe for every key: withdrawals, corrections, status ranking, timestamps, and ordering can affect resolution. Design the compact state around the actual rules, then validate it against fixtures and the offline scorer.

## What the handler currently does

The challenge asks for one clean output row per lab result from newline-delimited interface-engine logs containing HL7 messages. The output schema is:

`accession`, `test`, `patient_id`, `value`, `observed_at`, `unit`, `status`.

The submitted implementation has substantial parsing machinery, including JSON/message extraction, HL7 segment and field helpers, timestamp parsing, value and unit normalization, patient-ID extraction, and candidate reconciliation. The zero score should not be interpreted as proof that all of these pieces are wrong; the run did not return a completed result.

## Highest-impact correctness and robustness risks

The items below are code-review findings and priorities for the next iteration. Apart from the documented run failure, they are potential correctness gaps, not independently proven causes of the zero score.

### 1. Diagnose and fix resource growth first

Relevant areas: `Handler.__init__`, `Handler._parse()`, `Handler.process()`, `Handler._resolve()`, and `Handler.finalize()`.

The handler retains candidates in `self.groups` and fingerprints in `self.seen`. Because the output is assembled in `finalize()`, memory can grow with the number of distinct keys and messages.

**Recommended change:** design a bounded-state reducer that stores only the fields needed to compare candidates and select the winner. Add a memory test over a large synthetic stream, not only a few hundred lines. Track the number of groups, fingerprints, candidates, and peak memory during the test.

### 2. Emit a row for each eligible OBX result

The parser collects OBX segments but then selects the first recognized test and breaks out of the loop. A message containing multiple result OBXs can therefore lose additional results, despite the challenge requiring one row per result.

Simplified pattern in the current logic:

```python
for obx in obxs:
    # parse and recognize the test
    if recognized:
        candidate = ...
        break
```

**Recommended change:** create a candidate for each eligible result OBX. Keep comments and non-result OBXs from becoming lab-result rows. Then reconcile each candidate by the intended result key rather than limiting each message to one result.

### 3. Make segment splitting robust to extra segments and embedded line breaks

The handler's `split_segments()` handles CR, LF, and CRLF and has a fallback for segments separated by whitespace. However, the stream includes extra segments, batch envelopes, MLLP framing, doubled escapes, and embedded line breaks. These can interfere with locating the actual message and its result segments.

**Recommended change:** normalize the log/message envelope separately from HL7 parsing; preserve segment boundaries; test messages with extra segments before and between PID, OBR, and OBX. Do not assume a fixed segment order or that a message contains only one order/result.

### 4. Expand test, value, and unit normalization

The handler defines `TEST_CODES`, `parse_value()`, and `norm_unit()`. These provide a useful baseline but need broad fixture coverage for alternate LOINC/local codes, named tests, coded elements, SI/US unit variants, typed non-numeric values, comparators, flags embedded in values, and decimal/grouping conventions.

The reference file's helpers include explicit test-name/code, unit/code, status/code, and numeric parsing maps. Compare those helper cases against the handler's supported inputs instead of assuming the current maps are exhaustive.

**Important semantic issue:** `parse_value()` returns `None` for comparator-style values such as `<x` or `>x`. Confirm the challenge's expected representation for such results before discarding the comparator or bound.

### 5. Validate patient identifiers and merge handling

The handler extracts an MRN from PID fields with `pick_pid()`, but `APPLY_MERGES = False` disables the merge-resolution path. The stream contains multiple identifier forms, multiple issuing authorities, and merge messages.

**Recommended change:** select the patient identifier using both identifier type and assigning authority, and implement merge mapping only after validating the exact event semantics. Test a result arriving before and after a chart merge, including identifiers with prefixes, leading zeros, and check digits.

### 6. Use all valid sources of observation time

The current candidate construction relies on OBR-7 for collection time. The stream also includes time in SPM-17 or OBX fields, multiple timestamp widths, explicit offsets, sender-local timestamps without offsets, and run time alongside draw time.

The handler's `parse_ts()` and `sender_zone()` are a useful foundation, but the fallback and precedence rules need to match the challenge specification. Test timestamps from both sender zones, timestamps with and without offsets, fractional seconds, and daylight-saving transitions. Do not silently substitute the interface engine's processing time for the specimen observation time.

### 7. Resolve corrections, withdrawals, duplicates, and ordering deliberately

The handler defines a status ranking and deduplicates normalized message text with fingerprints. Its `_resolve()` chooses among candidates using truncation, status rank, timestamp, and sequence. These rules need explicit tests for revised results, W withdrawals, duplicate delivery, preliminary-to-final transitions, and messages arriving out of order.

**Recommended change:** specify precedence in tests before optimizing the state representation. A memory optimization must preserve the final result that the complete candidate history would have selected.

### 8. Make failures observable

`process()` catches and suppresses all exceptions and returns an empty list. That can keep the stream running, but it also hides parser defects and makes it difficult to diagnose why particular messages were dropped.

**Recommended change:** during local development, count and sample parse failures by category, and expose diagnostics outside the scored output path. Keep the required production interface unchanged and avoid logging sensitive patient data.

## Notes on `gold_submit.py`

The available `gold_submit.py` file contains parsing helpers for message extraction, HL7 escapes, patient identifiers, timestamps, values, units, and test codes. The checked-in file ends after `_test()`; it does **not** contain a visible `Handler`, `process()`, `finalize()`, or complete output-resolution pipeline. This review therefore compares the submitted handler to the available reference helpers and does not invent missing gold-pipeline behavior.

## Suggested implementation sequence

1. **Bound memory and prove the full stream completes.** This is the immediate reason the submitted run scored zero.
2. Add multi-OBX output handling and verify one row per eligible result.
3. Build fixtures for test codes, typed values, units, identifiers, timestamp precedence, and status transitions.
4. Validate batch/message extraction and unusual segment boundaries.
5. Compare the completed output against the offline scorer and monitor both memory and per-record work.

## Interface contract

Keep the required class interface:

```python
class Handler:
    def process(self, raw: str) -> list[dict]:
        # Consume one raw input line; normally emit no rows yet.
        return []

    def finalize(self) -> list[dict]:
        # Resolve compact retained state and return the final rows.
        ...
```

`process()` returning `[]` is appropriate if the evaluator expects reconciliation at end of stream. The critical change is to ensure the state retained between calls is compact enough that `finalize()` can actually run and return the reconciled rows.

## Conclusion

The first priority is clear: **the submitted run scored zero because memory growth prevented any output from being returned to the evaluator.** The offline score of 0.7883 suggests that the underlying parsing approach is promising, and the per-record work was close to the winner's. Focus next on compact, bounded-memory reconciliation, then fix the independently identified multi-OBX and edge-case risks without changing the required output semantics.
