# Week 3 – The Register: handler.py vs gold_submit.py

**Your score:** 0.7693 (#6 of 14)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | When rows are emitted | Empty `finalize`; online emit fights later corrections and chronological math. |
| 2 | Register → usage (offline, sorted) | Out-of-order registers break arrival-order deltas; large share of usage misses. |
| 3 | Interval alignment (start vs end) | “Stamped at the start” maps to the wrong half-hour or drops. |
| 4 | JSON / keys / CDC recovery | Dirty, nested, and CDC lines are a large recovery gap. |
| 5 | Meter ID normalization | Padding / missing dash / aliases lose meters. |
| 6 | Quality rank + null/units | Real read must never lose to a later estimate; broader nulls recover more cells. |

---

## 1. When rows are emitted

**Your code**
```python
# process L309–331
self.sent[(m, b)] = sig
return [out]

# finalize L335–336
def finalize(self):
    return []
```

**Gold code**
```python
# process L711–727 → only _merge into held, return []
# finalize L729–772 → sort, fill usage, return all rows
```

**Example input**  
Half-hour H gets an estimate, then later an actual for the same meter + interval.

**Your behavior**  
May emit on the estimate, then again on the actual (or lock early). `finalize` is always `[]`.

**Gold behavior**  
Keep one merged row in memory; emit once in `finalize`.

**Why it matters**  
A sample that only inspects `finalize` shows no output. Online emit also makes chronological register math harder.

**What to change**  
Emit nothing in `process`. Do all final work in `finalize`.

---

## 2. Register → usage (offline, sorted by time)

**Your code**
```python
# L294–307 _usage – arrival order
if usage is None and reg is not None and i > 0:
    d = reg - lst[i - 1][1]
    if d >= 0:
        row["usage_kwh"] = d
```

**Gold code**
```python
# L734–761 inside finalize
items.sort(key=lambda x: x[0])  # by interval_end
if usage is None and reg and prev_reg and ts - prev_ts == 1800:
    rec[0] = fmt3(reg - prev_reg)
```

**Example input**  
Registers arrive out of order: 10:30 first, then 10:00.

**Your behavior**  
Delta uses arrival order → wrong, negative, or skipped usage.

**Gold behavior**  
Sort by `interval_end`, then 10:00 → 10:30 delta is correct.

**Why it matters**  
Late / out-of-order reads are in the feed. Arrival-order math is the wrong model for running totals.

**What to change**  
Always group by meter, sort by `interval_end`, then walk consecutive 30-minute pairs.

---

## 3. Interval alignment (start vs end)

**Your code**
```python
# L208–221 bucket_interval + L278–281 _bucket
# snap any timestamp to nearest half-hour END
```

**Gold code**
```python
# L343–360 align_end
if is_start:
    dt = dt + timedelta(minutes=30)
# then snap
```

**Example input**  
Meter stamps **start** `10:00` for the 10:00–10:30 window.

**Your behavior**  
Bucket becomes `10:00` (wrong half-hour).

**Gold behavior**  
Shifts to `10:30` (correct end).

**Why it matters**  
“Stamped at the start” is an explicit condition; end-only snap maps those rows incorrectly or drops them.

**What to change**  
Detect start vs end fields; shift start stamps by +30 minutes before snapping.

---

## 4. JSON / keys / CDC recovery

**Your code**
```python
# L59–81 extract_json
# L84–95 flatten (2 levels)
# L98–109 canonical + ALIASES
```

**Gold code**
```python
# parse_raw L444+ · iter_records L585+
# multi-language keys, CDC unwrap,
# HTML unescape, truncated repair, kv-fallback
```

**Example input**  
`{"after": {"meter_id": "M-1", ...}}` or a broken/truncated JSON line.

**Your behavior**  
Miss nested CDC image or fail parse → drop.

**Gold behavior**  
Unwrap / repair and keep the reading.

**Why it matters**  
Dirty, nested, and CDC lines are a large recovery gap on the leaderboard conditions.

**What to change**  
Broaden aliases; add CDC unwrap and truncated-JSON repair.

---

## 5. Meter ID normalization

**Your code**
```python
# L112–116 norm_meter
return v if METER_RE.fullmatch(v) else None
# strict M-\d{7}
```

**Gold code**
```python
# L249–270 parse_meter_id
# M-? optional, pad to 7 digits, many aliases
```

**Example input**  
`"M1234567"` or `"m-123"`

**Your behavior**  
Reject → no row.

**Gold behavior**  
Normalize to padded `M-…` form and keep.

**Why it matters**  
Padding, missing dash, and alternate names lose meters that should score.

**What to change**  
Allow optional `-`, pad to 7 digits, expand aliases (`msn`, `serial`, …).

---

## 6. Quality merge

**Your code**
```python
# L269–276 _dedup + L284–292 _merge
# RANK actual=2 > estimated=1
# keep higher quality per exact timestamp
```

**Gold code**
```python
# L690–709 _merge
# higher rank replaces;
# same rank only fills null cells
```

**Example input**  
Estimate at 10:30, then actual at 10:30, then another estimate.

**Your behavior**  
Should keep actual (confirm rank never regresses).

**Gold behavior**  
Keeps actual; later estimate cannot overwrite.

**Why it matters**  
A real read must never lose to a later estimate.

**What to change**  
Keep an explicit rank; never let a lower rank replace a higher one.

---

## 7. Null & units

**Your code**
```python
# L163–196 norm_dec
# Decimal + unit from value or key suffix
```

**Gold code**
```python
# L171–223 parse_number
# broader nulls, HTML unescape, comma/decimal variants
```

**Example input**  
`"usage": "n/a"` or `"1,234.5 kWh"`

**Your behavior**  
May miss some null spellings or comma formats.

**Gold behavior**  
Treat as null or parse `1234.5`.

**Why it matters**  
More recovered numeric cells on messy head-end formats.

**What to change**  
Expand the null set and unit / decimal parsing.

---

## 8. `finalize` result

**Your code**
```python
def finalize(self):
    return []
```

**Gold code**
```python
# after group → sort → delta fill
return out  # full table
```

**Example input**  
You run the sample and inspect only the `finalize` return value.

**Your behavior**  
Always `[]`.

**Gold behavior**  
Full clean table.

**Why it matters**  
Explains “I run the sample and get no output.”

**What to change**  
Put the complete emit path in `finalize`.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}  # meter|interval → [usage, register, quality, rank]

    def process(self, raw: str) -> list[dict]:
        # parse → normalize → _merge into self.held
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # group by meter
        # sort by interval_end
        # fill missing usage from consecutive registers
        # return the complete list of rows
        return list_of_all_rows
```

This is the architecture top solutions use and what the scoring harness expects for maximum recovery.
