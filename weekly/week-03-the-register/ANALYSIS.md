# Week 3 – The Register: handler.py vs gold_submit.py

**Your score:** 0.7693 (#6 of 14)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

---

## 1. Comparison table

| Area | Your `handler.py` | Top-1 `gold_submit.py` | Impact |
|------|-------------------|------------------------|--------|
| **Output strategy** | Emit on every accepted change in `process()`; `finalize()` = `[]` | `process()` **always returns `[]`**; compute deltas + emit **everything** in `finalize()` | Same critical difference as Week 2 |
| **State** | `reads`, `regs`, `sent` – emit immediately after merge | `self.held = {meter\|interval: [usage, register, quality, rank]}` – accumulate only | Gold never emits until end |
| **Register → usage derivation** | Done **online** in `_usage` with binary-search sorted list (arrival order) | Done **offline** in `finalize`: sort each meter’s intervals, walk chronologically, fill missing usage from consecutive registers | Gold correctly handles out-of-order arrival |
| **Quality ranking** | Simple rank dict + keep higher quality | Explicit rank numbers + merge rules (higher rank wins; same rank fills nulls) | Similar intent, gold more careful |
| **Bucket / interval alignment** | Snap to 30-min with `bucket_interval` | `align_end` (handles start-stamped intervals by +30 min) | Gold recovers “Stamped at the start” |
| **JSON / key recovery** | Moderate (flatten 2 levels, alias map, some unit detection) | Extremely aggressive: many language variants of keys, CDC unwrap, HTML unescape, truncated JSON repair, kv-fallback | Gold recovers far more dirty lines |
| **Meter ID** | Strict `M-\d{7}` | Flexible: `M-?` + pad to 7 digits, many aliases | Gold recovers more meters |
| **Null / unit handling** | Good Decimal path | Broader null spellings + unit detection on both value and key name | Marginal gain |
| **`finalize()`** | `return []` | Walk every meter chronologically → derive missing usage → return **all** rows | Explains empty sample output |

---

## 2. What to improve

1. **Stop emitting in `process()`**  
   Same lesson as Week 2. Return `[]` from `process`, keep everything in memory, do the final register-delta walk and emit only in `finalize`.

2. **Derive usage offline, sorted by time**  
   Your current `_usage` uses the order registers arrived. Registers can arrive out of order (late reads, bursts). Gold groups by meter, sorts by `interval_end`, then walks consecutive 30-min pairs. That is the correct way to turn running totals into half-hour usage.

3. **Handle start-stamped intervals**  
   Some head-ends stamp the **beginning** of the half-hour. Gold’s `align_end(..., is_start=True)` adds 30 minutes. Your pure end-snap misses those rows or maps them to the previous bucket.

4. **Broader key & meter recovery**  
   Many more aliases (including non-English), flexible meter-id padding, CDC “after” image extraction, truncated-JSON repair.

5. **Quality / fill-in logic**  
   Real read must always beat a later estimate. Gold’s rank + merge rules make this explicit; double-check your rank never lets an estimate overwrite an actual.

---

## 3. Why `finalize` returns `[]` (and gold does not)

Exactly the same architectural reason as Week 2:

- You emit the best-known row the moment you see a usable reading → `finalize` has nothing left.
- Gold **never** emits in `process`. It only accumulates. In `finalize` it:
  1. Groups by meter  
  2. Sorts intervals  
  3. Fills missing `usage_kwh` from consecutive registers  
  4. Returns the complete list  

That is why running the sample against your code looks like “no output” when you inspect only the `finalize` return value, while the gold submission produces the full clean table.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}          # or whatever state you need

    def process(self, raw: str) -> list[dict]:
        # parse → normalize → update self.held
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # any final calculations (register deltas, …)
        # return the complete list of rows
        return list_of_all_rows
```
