# Week 2 – The Manifest: handler.py vs gold_submit.py

**Your score:** 0.8266 (#3 of 9)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | When rows are emitted | Empty `finalize` + possible 2nd-row penalty (−2 each). Architectural root cause. |
| 2 | Job-close / incomplete outputs | ~2.5% of stream; you recover almost none. |
| 3 | JSON recovery | Broken / logger / truncated lines are a real slice of the feed. |
| 4 | Keys & nesting | Nested fields and list-of-renditions are common; flat map misses them. |
| 5 | Rendition / codec / bitrate / duration | Name/size forms, toolchain tags, unit drift, sentinels. |
| 6 | Dedup / same-timestamp fill | Same-time replays can fill holes instead of being ignored. |

---

## 1. When rows are emitted

### Your current code (before)

```python
# process L263–282
self.records[key] = row
return [row]                    # emits immediately

# finalize L286–287
def finalize(self):
    return []                   # never emits anything
```

### Proposed change (after)

```python
class Handler:
    def __init__(self):
        self.held = {}          # key → best row
        self.jobs = {}          # unfinished job context (if needed)

    def process(self, raw: str) -> list[dict]:
        # parse → normalize → update self.held / self.jobs
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # finish pending jobs, resolve conflicts
        # return the complete list of rows
        return list(self.held.values())
```

### Explanation

- **Before**: rows are emitted online from `process`. A later update for the same key can produce a second row (penalty). A harness that only looks at `finalize` sees nothing.
- **After**: `process` only updates state. All rows are emitted once from `finalize`. No second-row penalty and the sample works.

**Example input**  
Line A: title `T-0000001`, 720p, packaged `10:00`.  
Later line B: same key, packaged `11:00`.

**Your behavior**  
Emit row for A immediately. Later emit an updated row for B (possible second-row penalty). `finalize` is always `[]`.

**Gold behavior**  
Hold both in memory. Emit **one** final row for that key only in `finalize`.

**Why it matters**  
You already lost 28 points this way (14 extra rows). Early emit also fights later corrections.

**What to change**  
Never `return [row]` from `process`. Collect everything; emit once in `finalize`.

---

## 2. Job-close / incomplete outputs

### Your current code (before)

```python
# No special path — same as normal records.
# Incomplete lines without a title fail check_quality and drop.
```

### Proposed change (after)

```python
# inside process / _process_record
if job and not complete:
    pending.append(rec)
elif closing:
    for output in pending:
        self._accept(_inherit(output, context))
```

### Explanation

- **Before**: an incomplete output that arrives before its title has nowhere to wait → it is dropped.
- **After**: park incomplete outputs under the job id; on the close line (or in `finalize`) inherit the title and emit.

**Example input**  
(1) Rendition line: `job_id=J`, no title.  
(2) Close line: `job_id=J`, `title_id=T-0000001`.

**Your behavior**  
No place to park the incomplete output → no row.

**Gold behavior**  
Park under `jobs[J]`. On close, inherit title → one row with `T-0000001`.

**Why it matters**  
“Job close lines” ≈ 2.5% of the stream; you recover almost none.

**What to change**  
Detect job id + close flag. Hold incomplete outputs until close (or until `finalize`).

---

## 3. JSON recovery

### Your current code (before)

```python
# L26–56 extract_json_payload
json.loads(...)
# or slice between first { and last }
# then one-level unwrap of message/data/payload
```

### Proposed change (after)

```python
# tolerant parser that:
# - strips logger prefixes
# - recovers truncated objects
# - unwraps nested message/data/payload recursively
# - tolerates unescaped quotes / comments
```

### Explanation

- **Before**: many logger-wrapped or truncated lines fail the strict path.
- **After**: a looser extractor recovers a much larger fraction of the dirty feed.

**Example input**  
`2024-01-01 INFO {"title_id":"T-1","variant":"720p",...}`

**Your behavior**  
Strict parse fails or misses the object → no row.

**Gold behavior**  
Finds `{...}` inside the logger line and recovers the record.

**Why it matters**  
Broken / logger-wrapped / truncated lines are a real condition in the feed.

**What to change**  
Prefer repair + tolerant parse over strict `json.loads` only.

---

## 4. Keys & nesting

### Your current code (before)

```python
# L59–76 KEY_ALIASES + L79–97 normalize_keys
# flat alias map only; no deep walk
```

### Proposed change (after)

```python
# recursive flatten of nested objects
# expand list-of-rendition payloads
```

### Explanation

- **Before**: nested fields are invisible to the flat alias map → row dropped.
- **After**: a recursive flatten + list expansion recovers the title/rendition.

**Example input**  
`{"video": {"title_id": "T-1", "variant": "720p"}}`

**Your behavior**  
Nested fields ignored → no title/rendition → drop.

**Gold behavior**  
Flattens `video` and keeps the row.

**Why it matters**  
Nesting and alternate key names are common; a flat map misses them.

**What to change**  
Flatten nested objects; expand list-of-rendition payloads.

---

## 5. Rendition / codec / bitrate / duration

### Your current code (before)

```python
# normalize_rendition – Np regex or width→height map
# normalize_codec – small CODEC_ALIASES dict
# bitrate / duration – simple number + min/h multipliers
```

### Proposed change (after)

```python
# broader nickname set (4k/uhd/fhd, WxH, nested labels)
# toolchain tags (avc1.…, hev1.…, libx264, av01.…)
# Decimal + richer unit table; reject sentinels (0 / −1 / NaN)
```

### Explanation

- **Before**: many real-world spellings and toolchain tags become null → cells lost.
- **After**: expanded alias / pattern tables + sentinel rejection recover more cells.

**Example input**  
`"variant": "1920x1080"` or `"4k"`, `"codec": "avc1.640028"`, `"bitrate": "5 Mbps"`, `"duration": -1`

**Your behavior**  
Rendition / codec null, possible mis-scaled bitrate, sentinel kept.

**Gold behavior**  
`1080p` / `2160p`, `h264`, 5000 kbps, null for sentinel.

**Why it matters**  
Name/size forms, toolchain tags, unit drift and sentinels are noticeable recovery gaps.

**What to change**  
Expand the alias / pattern sets; treat sentinels as null.

---

## 6. Dedup / same-timestamp fill

### Your current code (before)

```python
# L275–281
if existing and row["packaged_at"] <= existing["packaged_at"]:
    return []
self.records[key] = row
return [row]
```

### Proposed change (after)

```python
# newer instant wins
# same instant → fill nulls from the new line, mark conflicts
```

### Explanation

- **Before**: a same-timestamp replay that only carries the missing field is ignored.
- **After**: the missing cells are filled, producing a more complete row.

**Example input**  
Same key, same time: line1 has bitrate, line2 has codec only.

**Your behavior**  
Ignore line2 (not newer).

**Gold behavior**  
One row with both bitrate and codec.

**Why it matters**  
Same-timestamp replays can improve a row instead of being discarded.

**What to change**  
On equal time, fill missing cells instead of ignoring the new line.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}   # key → best row
        self.jobs = {}   # unfinished job context (if needed)

    def process(self, raw: str) -> list[dict]:
        # parse → normalize → update self.held / self.jobs
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # finish pending jobs, resolve conflicts
        # return the complete list of rows
        return list_of_all_rows
```

This is the architecture top solutions use and what the scoring harness expects for maximum recovery.
