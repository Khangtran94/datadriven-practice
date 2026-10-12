# Week 3 – The Register: handler.py vs gold_submit.py

## Result

- **Score:** 0.7693
- **Rank:** #6 of 14
- **Records recovered:** 786,280 / 900,971
- **Work per record:** 3.0× median
- **Statements:** 233

Files: [handler.py](./handler.py) and [gold_submit.py](./gold_submit.py). Function names are used as anchors because line numbers may shift. Analysis filename convention: `GPT_Analysis.md` (case-sensitive).

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

The handler inserts register readings into `self.regs[meter]` in sorted `interval_end` order using `find_pos()`. That is better than relying on raw arrival order, but it still derives usage only for the row currently being processed. When a late reading is inserted before an already-processed interval, the handler does not recalculate the usage of the later interval whose predecessor has changed.

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

The handler inserts 10:00 before 10:30, so the list itself becomes chronological. However, if 10:30 was processed first, its usage may already have been emitted. Inserting 10:00 later does not retract or recompute that earlier output. The 11:00 row may use the now-correct 10:30 predecessor, while the previously emitted 10:30 row can remain wrong or missing.

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

The handler does rank `actual` above `estimated`, so a lower-ranked estimate replay does not replace an accepted actual row for the same timestamp. The gap is in reconciliation: `_dedup()` rejects candidates whose quality rank is equal to or lower than the stored row, which means an equal-quality duplicate cannot contribute complementary non-null fields. Also, the merge is constrained to the fields and quality labels the handler recognizes.

### Gold code — _merge()

Gold assigns a quality rank. A higher-ranked reading replaces a lower-ranked reading; readings at the same rank can fill missing fields without discarding known values. This prevents a later estimate replay from regressing an actual reading.

### Example input

For the same meter and interval:
1. Estimate arrives with register 100.
2. Actual reading arrives with register 103.
3. A delayed estimate replay arrives with register 101.

### Your behavior

The actual reading replaces the estimate because its rank is higher. The later estimate replay is rejected, which is correct for this simple sequence. However, a same-rank record with a missing field can be rejected wholesale, so its complementary information is lost rather than merged.

### Gold behavior

Gold applies explicit precedence and can merge complementary non-null fields where the candidate rules permit it. The general goal is not only to prevent a lower-quality replay from winning, but also to retain useful fields without regressing a higher-quality candidate.

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

The gold parser and alignment logic normalize recognized timestamp formats, but the visible implementation does not clearly demonstrate explicit parsing of a trailing `CDT`/`CST` abbreviation. Do not assume every such value is correctly disambiguated without testing the exact input forms.

### Example input

~~~text
2026-11-01 01:30:00 CST
~~~

This illustrates the daylight-saving fall-back ambiguity: a local clock time in the repeated hour can refer to two different instants. The intended interpretation depends on the feed's timezone convention and available context.

### Your behavior

A naive local timestamp can be treated as UTC or normalized without resolving the intended offset. Distinct intervals can collapse to one key, or a row can shift to a neighboring interval.

### Gold behavior

Gold handles the timestamp forms implemented in its parser and then aligns intervals. For a trailing abbreviation such as `CST`, verify the behavior with a targeted test; the code does not clearly establish a complete named-timezone/DST solution for that exact form. The key lesson is to resolve timezone semantics before bucketing, rather than assuming every timestamp is UTC.

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
        out = []
        for (meter_id, interval_end), row in self.held.items():
            out.append({
                "meter_id": meter_id,
                "interval_end": interval_end,
                "usage_kwh": row["usage_kwh"],
                "register_kwh": row["register_kwh"],
                "quality": row["quality"],
            })
        return out
~~~

## Main lesson

The handler has useful building blocks for normalization and deduplication, but the problem is temporal: records may arrive late, be replayed, represent estimates, or encode interval starts rather than ends. **Hold candidates first; resolve identity, quality, and chronology together in finalize().** This makes output deterministic and gives register-derived usage the correct sequence of readings.

---

# Rerun update — Week 3 — The Register: complete before/after code

The handler derives usage while processing records and emits intermediate rows. Late readings can change predecessor relationships after an earlier row has already been emitted. Register-derived usage must be calculated after candidate reconciliation in chronological order.

## Code before — exact current handler.py

The following is the complete handler snapshot fetched for this rerun, included verbatim as the before reference.

```python
import json
import re
from datetime import datetime, timezone, timedelta
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

#### define 
QUALITY_MAP = {
    "a": "actual",
    "actual": "actual",
    "sub": "estimated",
    "e": "estimated",
    "est": "estimated",
    "estimated": "estimated",
    "estimate": "estimated",
    "substituted": "estimated",
}
METER_RE = re.compile(r"M-\d{7}")
RANK = {"actual": 2, "estimated": 1, None: 0}
ALIASES = {
    "meter_id": ["meter_id", "meterid", "meter", 'id',"mid", "msn"],
    "interval_end": ["interval_end", "intervalend", "end", "ts", "timestamp", "period_end",'event_time'],
    "kwh": ["kwh", "usage_kwh", "usage", "energy_kwh", "energy",
            "wh", "usage_wh", "energy_wh", "mwh", "usage_mwh", "energy_mwh"],
    "register": ["register", "register_kwh", "reg", "total_kwh", "cumulative",
                 "register_wh", "reg_wh", "total_wh", "register_mwh", "reg_mwh", "total_mwh"],
    "quality": ["quality", "q", "read_type", "status",'flag'],
}

### Factor for unit in energy
UNIT_FACTOR = {"wh": Decimal("0.001"), "kwh": Decimal("1"), "mwh": Decimal("1000")}
NULL_STRINGS = {"", "null", "none", "n/a", "na", "nan", "-", "--"}
LOOKUP = {re.sub(r"[^a-z0-9]", "", a): c for c, al in ALIASES.items() for a in al}
SEQ_KEYS = ("_seq", "seq", "received_at")
VAL_RE = re.compile(r"([-+]?[\d.,]*\d(?:[eE][-+]?\d+)?)\s*([A-Za-z]*)")

### Normalize key column
def _normalize_key_name(k):
    """Collapse a raw key to a bare lowercase alnum string so
    'Title_ID', 'title-id', 'titleId' all compare equal."""
    return re.sub(r"[^a-z0-9]", "", str(k).lower())

def norm_unit(u):
    if not isinstance(u, str):
        return None
    u = re.sub(r"[^a-z]", "", u.lower())
    return u if u in UNIT_FACTOR else None

def key_unit(k):
    nk = _normalize_key_name(k)
    if nk.endswith("mwh"):
        return "mwh"
    if nk.endswith("kwh"):
        return "kwh"
    if nk.endswith("wh"):
        return "wh"
    return None

### Check json format first:
def extract_json(raw):
    if not isinstance(raw,str):
        return None
    raw = raw.strip()
    try: 
        record = json.loads(raw)
        if isinstance(record, dict):
            return record
    except json.JSONDecodeError:
        pass
    
    ### Recover JSON from surronding text:
    start = raw.find('{')
    end = raw.rfind('}')
    if start == -1 or end <= start:
        return None
    try:
        record = json.loads(raw[start:end+1])
        if isinstance(record, dict):
            return record
    except json.JSONDecodeError:
        return None
    return None

### Flatten if need:
def flatten(obj, depth=0):
    """Pull fields out of one or two levels of sub-objects."""
    flat = {}

    for k, v in obj.items():
        if isinstance(v, dict) and depth < 2:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)

    return flat

### Check lookup and convert to the format
def canonical(obj):
    out, units, extra = {}, {}, {}
    for k, v in flatten(obj).items():
        c = LOOKUP.get(_normalize_key_name(k))
        if c is not None:
            if out.get(c) is None:
                out[c] = v
                if c in ("kwh", "register"):
                    units[c] = key_unit(k)
        elif k in SEQ_KEYS:
            extra[k] = v
    return out, units, extra

### Format column:
def norm_meter(v):
    if not isinstance(v, str):
        return None
    v = v.strip().upper()
    return v if METER_RE.fullmatch(v) else None

def norm_time(time_check):
    if time_check is None or isinstance(time_check, bool):
        return None
    # Unix timestamp
    if isinstance(time_check, (int, float)):
        try:
            num = float(time_check)
            # Treat large timestamps as milliseconds
            if num > 1e11:
                num /= 1000
            dt = datetime.fromtimestamp(num, tz=timezone.utc)
            return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OSError, ValueError, OverflowError):
            return None
    if not isinstance(time_check, str):
        return None
    time_check = time_check.strip()

    if not time_check:
        return None
    # Numeric string -> Unix timestamp
    try:
        num = float(time_check)
        # Treat large timestamps as milliseconds
        if num > 1e11:
            num /= 1000
        dt = datetime.fromtimestamp(num, tz=timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, OSError, OverflowError):
        pass
    # ISO 8601
    try:
        dt = datetime.fromisoformat(
            time_check.replace("Z", "+00:00")
        )
        # No timezone -> assume UTC
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        else:
            dt = dt.astimezone(timezone.utc)
        return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return None

### unit energy
def norm_dec(v, field_unit=None):
    """Normalize energy value to Decimal kWh, 3 decimal places."""
    if v is None or isinstance(v, bool):
        return None
    unit = None
    if isinstance(v, str):
        s = v.strip()
        if s.lower() in NULL_STRINGS:
            return None
        m = VAL_RE.fullmatch(s)
        if not m:
            return None
        text, suffix = m.group(1), m.group(2)
        if suffix:
            unit = norm_unit(suffix)
            if unit is None:
                return None
        v = text
    elif not isinstance(v, (int, float)):
        return None
    unit = unit or norm_unit(field_unit) or "kwh"
    try:
        d = Decimal(str(v))
    except InvalidOperation:
        return None
    if not d.is_finite() or d < 0:
        return None
    return (
        d * UNIT_FACTOR[unit]
    ).quantize(
        Decimal("0.001"),
        rounding=ROUND_HALF_UP
    )

### Quality
def norm_quality(v):
    if v is None:
        return None
    if isinstance(v, (int, float)):
        v = str(v)
    if not isinstance(v, str):
        return None
    return QUALITY_MAP.get(v.strip().lower())

### Bucket
def bucket_interval(ts):
    try:
        dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except (ValueError, AttributeError):
        return None
    base = dt.replace(minute=0, second=0, microsecond=0)
    off = dt - base
    if off == timedelta(0):
        b = base
    elif off <= timedelta(minutes=30):
        b = base + timedelta(minutes=30)
    else:
        b = base + timedelta(hours=1)
    return b

### Clean + check quality inside already
def clean(rec, units=None):
    if not isinstance(rec, dict):
        return None
    units = units or {}
    meter = norm_meter(rec.get("meter_id"))
    if meter is None:
        return None
    interval = norm_time(rec.get("interval_end"))
    if interval is None:
        return None
    return {
        "meter_id": meter,
        "interval_end": interval,
        "usage_kwh": norm_dec(
            rec.get("kwh"),
            field_unit=units.get("kwh"),
        ),
        "register_kwh": norm_dec(
            rec.get("register"),
            field_unit=units.get("register"),
        ),
        "quality": norm_quality(rec.get("quality")),
    }


#### Handler:
SNAP = True           
EMIT_UPDATES = False   

def find_pos(lst, key):
    lo, hi = 0, len(lst)
    while lo < hi:
        mid = (lo + hi) // 2
        if lst[mid][0] < key:
            lo = mid + 1
        else:
            hi = mid
    return lo

class Handler:
    def __init__(self):
        self.reads = {}   # (meter, bucket) -> {interval_end: row}
        self.regs = {}    # meter -> [(bucket, register)] đã sort
        self.sent = {}    # (meter, bucket) -> tuple giá trị đã emit

    def _dedup(self, m, b, row):
        reads = self.reads.setdefault((m, b), {})
        ts = row["interval_end"]
        old = reads.get(ts)
        if old is not None and RANK[row["quality"]] <= RANK[old["quality"]]:
            return False
        reads[ts] = row
        return True

    def _bucket(self, ts):
        if not SNAP:
            return ts
        b = bucket_interval(ts)
        return b.strftime("%Y-%m-%dT%H:%M:%SZ") if b else None

    def _merge(self, m, b):
        reads = self.reads[(m, b)]
        rs = [reads[t] for t in sorted(reads)]
        usage = next((r["usage_kwh"] for r in reversed(rs) if r["usage_kwh"] is not None), None)
        reg = next((r["register_kwh"] for r in reversed(rs) if r["register_kwh"] is not None), None)
        qs = {r["quality"] for r in rs}
        quality = "actual" if "actual" in qs else ("estimated" if "estimated" in qs else None)
        return {"meter_id": m, "interval_end": b,
                "usage_kwh": usage, "register_kwh": reg, "quality": quality}

    def _usage(self, m, b, row):
        lst = self.regs.setdefault(m, [])
        i = find_pos(lst, b)
        reg = row["register_kwh"]
        if row["usage_kwh"] is None and reg is not None and i > 0:
            d = reg - lst[i - 1][1]
            if d >= 0:
                row["usage_kwh"] = d
        if reg is not None:
            if i < len(lst) and lst[i][0] == b:
                lst[i] = (b, reg)
            else:
                lst.insert(i, (b, reg))
        return row

    def process(self, raw):
        try:
            payload = extract_json(raw)
            if payload is None:
                return []
            normalized, units, _ = canonical(payload)
            row = clean(normalized, units)
            if row is None:
                return []

            m = row["meter_id"]
            b = self._bucket(row["interval_end"])
            if b is None:
                return []
            if not self._dedup(m, b, row):
                return []

            out = self._usage(m, b, self._merge(m, b))
            sig = (out["usage_kwh"], out["register_kwh"], out["quality"])
            if (m, b) in self.sent and (not EMIT_UPDATES or self.sent[(m, b)] == sig):
                return []
            self.sent[(m, b)] = sig
            return [out]
        except (TypeError, ValueError, KeyError, AttributeError, OverflowError, OSError):
            return []

    def finalize(self):
        return []
```

## Code after — proposed change

```python
class Handler:
    def __init__(self):
        self.held = {}  # (meter_id, interval_end) -> merged candidate

    def process(self, raw: str) -> list[dict]:
        try:
            obj = parse_raw(raw)
            if obj is None:
                return []
            for rec in iter_records(obj):
                try:
                    row = clean_record(rec)
                    if row is None:
                        continue
                    meter, end, usage, register, quality, rank = row
                    self._merge((meter, end), usage, register, quality, rank)
                except (ValueError, TypeError, OverflowError,
                        InvalidOperation, RecursionError):
                    continue
        except (ValueError, TypeError, OverflowError,
                InvalidOperation, RecursionError):
            pass
        return []

    def finalize(self) -> list[dict]:
        by_meter = defaultdict(list)
        for (meter, end), rec in self.held.items():
            by_meter[meter].append((end, rec))
        for items in by_meter.values():
            items.sort(key=lambda item: item[0])
            prev_ts = prev_reg = None
            for end, rec in items:
                ts = parse_canonical_utc(end)
                reg = parse_decimal_or_none(rec[1])
                if (rec[0] is None and reg is not None
                        and prev_reg is not None and prev_ts is not None
                        and ts - prev_ts == 1800):
                    delta = reg - prev_reg
                    if delta >= 0:
                        rec[0] = format_kwh(delta)
                if reg is not None:
                    prev_ts, prev_reg = ts, reg
                else:
                    prev_ts = prev_reg = None
        return [
            {'meter_id': meter, 'interval_end': end,
             'usage_kwh': rec[0], 'register_kwh': rec[1],
             'quality': rec[2]}
            for (meter, end), rec in self.held.items()
        ]
```

This is an implementation pattern, not a drop-in file: parse_canonical_utc and format_kwh must implement the exact schema and precision, and _merge must preserve quality precedence and same-rank field merging. Reuse matching helpers and output formatting from gold_submit.py.

Validation: process() returns []; start-stamped timestamps shift to interval end before keying; late reads are sorted before deriving usage; derive usage only for adjacent valid reads exactly 30 minutes apart with non-negative deltas; never overwrite explicit usage; test quality precedence, DST, CDC after-images, quoted JSON, null sentinels, and Wh/MWh conversion.

## Learning notes

- The README's score, row counts, and named stream conditions are evidence; root-cause prioritization is an engineering assessment unless controlled tests prove it.
- Make one architectural change at a time, then compare exact output values and row counts against the task contract.
- Do not treat a proposal as drop-in code until all referenced helpers, constants, and dependencies are present and the full challenge test passes.
- Keep memory, identity/deduplication, event-time ordering, status precedence, and output lifecycle as separate invariants; optimizing one must not silently break another.
