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

### Your current code (before)

```python
# process L309–331
self.sent[(m, b)] = sig
return [out]                    # emits immediately

# finalize L335–336
def finalize(self):
    return []                   # never emits anything
```

### Proposed change (after)

```python
class Handler:
    def __init__(self):
        self.held = {}          # meter|interval → best candidate

    def process(self, raw: str) -> list[dict]:
        # parse → normalize → _merge into self.held
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # group by meter, sort by interval_end
        # fill missing usage from consecutive registers
        # return the complete list of rows
        return list_of_all_rows
```

### Explanation

- **Before**: rows are emitted online. A later actual can produce a second row or lock an estimate too early. A harness that only inspects `finalize` sees nothing.
- **After**: all merging and chronological math happen in `finalize`. One clean table is emitted once.

**Example input**  
Half-hour H gets an estimate, then later an actual for the same meter + interval.

**Your behavior**  
May emit on the estimate, then again on the actual (or lock early). `finalize` is always `[]`.

**Gold behavior**  
Keep one merged row in memory; emit once in `finalize`.

**Why it matters**  
Online emit fights later corrections and makes chronological register math harder.

**What to change**  
Emit nothing in `process`. Do all final work in `finalize`.

---

## 2. Register → usage (offline, sorted by time)

### Your current code (before)

```python
# L294–307 _usage – arrival order
if usage is None and reg is not None and i > 0:
    d = reg - lst[i - 1][1]
    if d >= 0:
        row["usage_kwh"] = d
```

### Proposed change (after)

```python
# inside finalize
items.sort(key=lambda x: x[0])          # by interval_end
if usage is None and reg and prev_reg and ts - prev_ts == 1800:
    rec[0] = fmt3(reg - prev_reg)
```

### Explanation

- **Before**: deltas are computed in arrival order. Out-of-order registers produce wrong, negative, or missing usage.
- **After**: group by meter, sort by `interval_end`, then walk consecutive 30-minute pairs. The math becomes correct regardless of arrival order.

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

### Your current code (before)

```python
# L208–221 bucket_interval + L278–281 _bucket
# snap any timestamp to nearest half-hour END
```

### Proposed change (after)

```python
# detect start vs end fields
if is_start:
    dt = dt + timedelta(minutes=30)
# then snap to half-hour end
```

### Explanation

- **Before**: a start stamp `10:00` is snapped to the wrong half-hour.
- **After**: start stamps are shifted +30 minutes before snapping, so they land on the correct end.

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

### Your current code (before)

```python
# L59–81 extract_json
# L84–95 flatten (2 levels)
# L98–109 canonical + ALIASES
```

### Proposed change (after)

```python
# multi-language keys, CDC unwrap,
# HTML unescape, truncated repair, kv-fallback
```

### Explanation

- **Before**: nested CDC images and truncated / dirty lines are frequently dropped.
- **After**: broader recovery keeps more readings.

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

### Your current code (before)

```python
# L112–116 norm_meter
return v if METER_RE.fullmatch(v) else None
# strict M-\d{7}
```

### Proposed change (after)

```python
# M-? optional, pad to 7 digits, many aliases (msn, serial, …)
```

### Explanation

- **Before**: missing dash, short numbers, or alternate names are rejected.
- **After**: light normalisation recovers the meter.

**Example input**  
`"M1234567"` or `"m-123"`

**Your behavior**  
Reject → no row.

**Gold behavior**  
Normalize to padded `M-…` form and keep.

**Why it matters**  
Padding, missing dash, and alternate names lose meters that should score.

**What to change**  
Allow optional `-`, pad to 7 digits, expand aliases.

---

## 6. Quality rank + null/units

### Your current code (before)

```python
# L269–276 _dedup + L284–292 _merge
# RANK actual=2 > estimated=1
# keep higher quality per exact timestamp
```

### Proposed change (after)

```python
# higher rank always replaces
# same rank only fills null cells
# broader null set + unit / decimal parsing
```

### Explanation

- **Before**: the rank logic is mostly correct, but some null spellings and number formats are still missed.
- **After**: explicit rank + richer null / unit handling recovers more cells without letting a later estimate overwrite a real read.

**Example input**  
Estimate at 10:30, then actual at 10:30, then another estimate.  
or `"usage": "n/a"`, `"1,234.5 kWh"`

**Your behavior**  
Should keep actual (confirm rank never regresses). Some nulls / formats still lost.

**Gold behavior**  
Keeps actual; later estimate cannot overwrite. Broader parsing recovers more cells.

**Why it matters**  
A real read must never lose to a later estimate. More recovered numeric cells on messy head-end formats.

**What to change**  
Keep an explicit rank; never let a lower rank replace a higher one. Expand the null set and unit / decimal parsing.

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
