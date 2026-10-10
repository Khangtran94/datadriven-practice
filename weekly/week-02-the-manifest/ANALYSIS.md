# Week 2 – The Manifest: handler.py vs gold_submit.py

**Your score:** 0.8266 (#3 of 9)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

---

## 1. Comparison table

| Area | Your `handler.py` | Top-1 `gold_submit.py` | Impact |
|------|-------------------|------------------------|--------|
| **Output strategy** | `process()` emits the current best row for a key immediately; `finalize()` returns `[]` | `process()` **always returns `[]`**; all rows are emitted only in `finalize()` | Critical design difference |
| **State** | `self.records = {(title_id, rendition): row}` | `self.held = {(title, rendition): (instant, compact_row)}` + `self.jobs` for unfinished encoding jobs | Gold keeps job context across lines |
| **Job close lines** | Ignored / treated as normal records | Explicitly handled: incomplete outputs wait for job close, then inherit title/context | You miss “Job close lines” (2.5% of stream, almost 0% recovered) |
| **JSON parsing** | Strict `json.loads` + simple `{…}` slice + one-level unwrap of message/data/payload | Custom `_LooseJSON` parser + `raw_decode` + recursive unwrapping of nested containers/lists | Gold recovers broken/truncated/logger lines far better |
| **Key aliases** | Small fixed list | Very large key lists + recursive flatten of containers (`payload`, `data`, `video`, `job`…) | Gold handles nesting & exotic key names |
| **Rendition** | Width map + simple `Np` / width regex | Width map + height + `4k`/`uhd`/`fhd` aliases + dimension parsing (`1920x1080`) + label extraction | Gold recovers more “Rung as size/name/number” |
| **Codec** | Small alias dict | Full RFC-6381 / library names (`avc1.…`, `hev1.…`, `libx264`, …) | Gold handles more codec tags |
| **Bitrate / Duration** | Basic number + unit | Decimal + many units (bps/Mbps/k, ms/us, ISO-8601 duration, timecode) + sentinel rejection | Gold more robust on unit drift |
| **Dedup rule** | Keep newer `packaged_at` only | Keep newer instant; same-instant → fill nulls, mark conflicts as `None` | Slightly different conflict handling |
| **`finalize()`** | `return []` | Drain remaining jobs → build **all** final rows and return them | This is why sample runs show no output with your code |

---

## 2. What to improve

1. **Change the emit model**  
   Most top solutions (including gold) do **zero emission in `process()`** and return everything from `finalize()`.  
   Reason: later lines can improve or complete an earlier key (job-close, late re-delivery, same-timestamp fill). Emitting early locks you into a suboptimal row and can produce the “second row for a key” penalty (14 rows / –28 points on your run).

2. **Handle job-close / incomplete outputs**  
   Gold keeps a `self.jobs` dict. Incomplete rendition lines wait for the job-close line that carries the title, then inherit context. Your code never does this → almost total loss on that 2.5% condition.

3. **Stronger JSON recovery**  
   Logger prefixes, BOM, trailing junk, unescaped quotes, truncated objects. Gold’s `_LooseJSON` + repair path recovers a large fraction of the “Broken JSON structure” / “Truncated lines” cases you currently miss.

4. **Richer normalizers**  
   Especially rendition (aliases + WxH), codec (full tags), bitrate/duration units, and null sentinels (`0`, `-1`, `NaN`).

5. **Never emit twice for the same key**  
   Keep only the latest (or best) version in memory and emit once at the end.

---

## 3. Why `finalize` returns `[]` and sample shows no output

```python
# Your code
def process(...):
    ...
    self.records[key] = row
    return [row]          # ← you emit immediately

def finalize(self):
    return []             # ← nothing left
```

On the platform the sample / grader often calls `process` on every line and then calls `finalize` once. Because you already returned the rows from `process`, `finalize` is empty → “no output” when someone only looks at the final call, or when the harness expects the complete set only at the end.

Gold does the opposite:

```python
def process(...):
    ...  # only update self.held / self.jobs
    return []             # never emit here

def finalize(self):
    # finish pending jobs
    ...
    return [dict(...) for every held key]   # all rows here
```

That is why gold’s sample run produces the full table and yours appears empty if you only inspect `finalize`.

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
        # any final calculations (job inheritance, …)
        # return the complete list of rows
        return list_of_all_rows
```
