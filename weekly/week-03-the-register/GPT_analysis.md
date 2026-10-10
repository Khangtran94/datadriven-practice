# Week 3 – The Register: handler.py vs gold_submit.py

## Result

- **Score:** 0.7693
- **Rank:** #6 of 14
- **Records recovered:** 786,280 / 900,971
- **Work per record:** 3.0× median
- **Statements:** 233

Files: [handler.py](./handler.py) and [gold_submit.py](./gold_submit.py). Function names are used as anchors because line numbers may shift.

## Impact ranking

| Priority | Gap | Evidence / impact |
|---:|---|---|
| 1 | Register-derived usage computed before chronological ordering | usage_kwh has 105,002 wrong and 119,338 missed values. The handler derives deltas from the current register list, while gold sorts and fills missing usage in finalize. |
| 2 | Interval start/end alignment | Start-stamped records are 5% of the stream and only 7% recovered. A start timestamp must be converted to the interval end, not simply snapped to a half-hour boundary. |
| 3 | Quality precedence and estimate replay | “Fill-in then real read” is 10% of the stream and only 55% recovered. A later estimate must not overwrite a higher-quality actual reading. |
| 4 | JSON envelopes, CDC, and malformed payloads | CDC envelopes are 2.5% of the stream and 50% recovered; JSON-quoted strings are 2% and 7% recovered; broken JSON is 2% and 34% recovered. |
| 5 | Local wall time and daylight-saving ambiguity | CDT/CST timestamps are 8% of the stream and only 26% recovered. The fall-back hour can occur twice, so a naive local timestamp is not always uniquely identifiable. |
| 6 | Meter IDs, numeric parsing, and quality flags | meter_id and interval_end have 87% correct and 114,691 missed each. Usage, register, and quality columns also have substantial wrong/missed counts. |

This ranking combines column-level evidence and likely root causes; the README does not give exact score loss per condition. Output lifecycle is also an architectural concern: the handler emits during process and returns nothing from finalize, while gold produces the final table after state reconciliation.

---

## 1. Sort register readings before deriving usage

### Your code — handler.py, _usage()

~~~python
usage = current_register - previous_register
~~~

The implementation derives usage from neighboring entries in its current register list, which can reflect arrival order rather than chronological interval order.

### Gold code — gold_submit.py, finalize()

The gold implementation groups readings by meter, sorts each meter's intervals by interval_end, and derives usage only when the current and previous timestamps are exactly 1,800 seconds apart. It also checks that the register delta is non-negative.

### Example input

The same meter's readings arrive out of order:

| Arrival order | interval_end | register_kwh |
|---:|---|---:|
| 1 | 10:30 | 140 |
| 2 | 10:00 | 130 |
| 3 | 11:00 | 155 |

Assume these intervals share the same date/time context and are 30 minutes apart.

### Your behavior

If the code calculates deltas from the current list sequence, the 10:00 reading can be treated as preceding 10:30 even though it arrived later. This can produce a negative delta or attach usage to the wrong interval.

### Gold behavior

Gold sorts chronologically first. It derives usage from adjacent valid register readings only when the time gap is exactly 30 minutes and the register delta is non-negative. Arrival order is not treated as event-time order.

### Why it matters

The README reports 105,002 wrong and 119,338 missed usage_kwh values. Register deltas depend on sequence, so this cannot safely be solved by processing each record independently.

### What to change

Hold rows by meter and interval identity. In finalize, sort by interval_end, then derive missing usage from the preceding valid register only when the gap is exactly 30 minutes and the delta is valid. Preserve explicit usage rather than overwriting it with a derived value.

---

## 2. Align start-stamped intervals to the interval end

### Your code — bucket_interval() / _bucket()

The handler snaps a timestamp to a half-hour bucket. That does not distinguish a timestamp representing the beginning of an interval from one representing its end.

### Gold code — align_end()

Gold interprets the source timestamp convention and adds 30 minutes for records stamped at interval start before aligning the result to the required interval-end representation.

### Example input

A reading is stamped at 10:00, and the source convention says the timestamp marks the start of a 30-minute interval.

### Your behavior

The timestamp is bucketed at or around 10:00, so the row can be assigned to the wrong interval end.

### Gold behavior

The timestamp is shifted to 10:30 and normalized to the required interval-end key.

### Why it matters

Start-stamped records are 5% of the stream, with only 7% recovered. An off-by-one-interval error can affect both identity and the register delta for neighboring intervals.

### What to change

Make timestamp interpretation explicit: determine whether a source stamps interval start or end, apply the offset, then normalize to the canonical half-hour interval end. Test exact boundaries and values with seconds or timezone offsets.

---

## 3. Preserve quality precedence when actual readings replace estimates

### Your code — _dedup() and _merge()

The handler tracks emitted signatures and merges records, but its quality handling is not as robust as the gold rule when an estimate is followed by an actual reading and then a replayed estimate.

### Gold code — _merge()

Gold assigns a quality rank. A higher-ranked reading replaces a lower-ranked reading; readings at the same rank can fill missing fields without discarding known values. This prevents a later estimate replay from regressing an actual reading.

### Example input

For the same meter and interval:
1. Estimate arrives with register 100.
2. Actual reading arrives with register 103.
3. A delayed estimate replay arrives with register 101.

### Your behavior

The selected value depends on the handler's merge/dedup path and arrival ordering. Without a strict quality-rank invariant, a lower-quality replay can affect the final candidate or be treated as an ordinary duplicate.

### Gold behavior

The actual reading has a higher quality rank than an estimate and remains the chosen value after the later estimate replay.

### Why it matters

The README says “fill-in then real read” accounts for 10% of the stream, with only 55% recovered. Correct handling requires reconciling competing candidates for the same logical interval.

### What to change

Represent quality as an explicit rank or ordered enum. Apply the same merge function to every candidate regardless of arrival order: higher quality wins; equal quality fills nulls; conflicting equal-rank values use a deterministic policy. Signature-only deduplication is not a substitute for precedence.

---

## 4. Unwrap CDC envelopes and recover the actual row

### Your code — extract_json(), flattening, and key normalization

The handler parses JSON and flattens a limited number of levels. This works for simple payloads but does not cover every wrapper/envelope shape or malformed logger representation.

### Gold code — parse_raw() and iter_records()

Gold handles quoted JSON strings, nested envelopes, CDC-style records, HTML-unescaped content, truncated repair attempts, and key/value fallback patterns. For CDC updates, the after-image is the current row; the before-image is the previous state.

### Example input

~~~json
{
  "op": "u",
  "before": {"meter_id": "M-0000123", "register_kwh": 130},
  "after": {"meter_id": "M-0000123", "register_kwh": 133, "interval_end": "2026-09-01T10:30:00Z"}
}
~~~

### Your behavior

If the outer envelope is treated as the record or the wrong nested object is selected, canonical fields may not be found or the stale before-image may be used.

### Gold behavior

The gold record iterator recognizes the envelope and extracts the after-image for the current row.

### Why it matters

CDC envelopes are 2.5% of the stream and 50% recovered. JSON-quoted strings and broken JSON are also weak conditions. These need to be handled before domain normalization.

### What to change

Separate raw parsing from record extraction. Support known envelope types explicitly and define which image represents current state. Keep recovery bounded and deterministic; malformed input should not cause fabricated values.

---

## 5. Interpret local timestamps with timezone and DST rules

### Your code

The timestamp/bucketing path does not reliably resolve naive local timestamps expressed using CDT/CST conventions.

### Gold code

The gold alignment/parsing path recognizes timezone information and applies the feed-specific rules used to normalize timestamps to interval ends.

### Example input

~~~text
2026-11-01 01:30:00 CST
~~~

This illustrates the daylight-saving fall-back ambiguity: a local clock time in the repeated hour can refer to two different instants. The intended interpretation depends on the feed's timezone convention and available context.

### Your behavior

A naive local timestamp can be treated as UTC or normalized without resolving the intended offset. Distinct intervals can collapse to one key, or a row can shift to a neighboring interval.

### Gold behavior

Gold applies source-specific timestamp handling before interval alignment. The key lesson is to resolve timezone semantics before bucketing, rather than assuming every timestamp is UTC.

### Why it matters

CDT/CST records are 8% of the stream and only 26% recovered. The repeated fall-back hour makes a simple fixed offset insufficient for all cases.

### What to change

Define timezone handling as an explicit source rule. Parse named offsets where present, preserve unambiguous offsets, and test both occurrences of the repeated DST hour. If the feed lacks enough information to disambiguate a naive timestamp, document the chosen rule rather than silently guessing.

---

## 6. Normalize meter IDs, numeric values, nulls, and quality labels

### Your code

The handler's norm_meter() expects a strict M-####### form. Numeric and quality normalization covers common forms but not the full variety of source representations.

### Gold code

The gold implementation's parse_meter_id() accepts more input variants before producing the canonical meter ID. Its numeric parser handles more null spellings and number formats, and its quality mapping gives known categories a consistent rank.

### Example input

~~~json
{
  "meter_id": "m123",
  "usage_kwh": "1,25",
  "register_kwh": "1.250",
  "quality": "estimated"
}
~~~

This is illustrative: decimal-separator interpretation must follow the source convention rather than assuming comma and dot always mean the same thing.

### Your behavior

The strict meter pattern rejects IDs that could be normalized under the feed contract. A narrow numeric parser may reject a valid number or misinterpret a sentinel/null-like string. A narrow quality map may fail to rank a valid maker-specific flag.

### Gold behavior

Gold normalizes recognized meter variants, parses broader numeric/null forms, and maps quality labels into a consistent precedence order.

### Why it matters

The README reports 87% correct but 114,691 missed for both meter_id and interval_end. It also shows large wrong/missed counts for usage, register, and quality. Missing identity fields can prevent an otherwise usable row from being emitted.

### What to change

- Normalize meter IDs according to the exact output contract; test casing, whitespace, optional separators, and zero-padding.
- Treat null sentinels as missing values.
- Parse numeric strings according to explicit locale/unit rules; avoid ambiguous blanket replacements.
- Map known quality labels to a rank, keeping unknown flags distinct from actual readings.
- Test each canonicalizer independently before testing the full stream.

---

## 7. Use finalize() as the reconciliation boundary

### Your code

~~~python
# process() emits an output row when it considers the record ready
return [out]

def finalize(self):
    return []
~~~

### Gold code

Gold process merges normalized candidates into held state and returns an empty list. finalize groups by meter, sorts intervals, derives missing usage where valid, and returns the final rows.

### Example input

A register update arrives first, then a late reading for an earlier interval. The earlier reading changes the predecessor relationship used to derive usage.

### Your behavior

A row can be emitted before later events provide the information needed to deduplicate, choose the best quality, or calculate usage chronologically. An empty finalize cannot correct already emitted output.

### Gold behavior

All candidates are reconciled before final rows are emitted. The final table is built from the best candidate per meter/interval, and derived values are computed in event-time order.

### Why it matters

This architecture supports late readings, duplicate delivery, quality precedence, and register-derived usage. These conditions are explicitly present in the README, so finalization is part of correctness, not just code organization.

### What to change

Return [] from process. Keep one candidate per logical meter/interval, merge candidates with explicit quality precedence, and defer register-derived usage until all input has been seen.

---

## Recommended pattern skeleton

~~~python
class Handler:
    def __init__(self):
        self.held = {}  # (meter_id, interval_end) -> best normalized row

    def process(self, raw: str) -> list[dict]:
        # Parse and unwrap input.
        # Extract the current record (e.g. CDC after-image).
        # Normalize meter ID, interval end, numeric fields, and quality.
        # Merge candidate into self.held using quality precedence.
        # NEVER emit final rows from process().
        return []

    def finalize(self) -> list[dict]:
        # Group held rows by meter.
        # Sort each meter's rows by interval_end.
        # Derive missing usage only from valid consecutive register reads
        # exactly 30 minutes apart; do not overwrite explicit usage.
        # Return the complete final table.
        return list_of_all_rows
~~~

## Main lesson

The handler has useful building blocks for normalization and deduplication, but the problem is temporal: records may arrive late, be replayed, represent estimates, or encode interval starts rather than ends. **Hold candidates first; resolve identity, quality, and chronology together in finalize().** This makes output deterministic and gives register-derived usage the correct sequence of readings.
