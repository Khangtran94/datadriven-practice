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

**Your code**
```python
# process L263–282
self.records[key] = row
return [row]

# finalize L286–287
def finalize(self):
    return []
```

**Gold code**
```python
# process → always return []
# finalize L633–648 → return all held rows
```

**Example input**  
Line A: title `T-0000001`, 720p, packaged `10:00`.  
Later line B: same key, packaged `11:00`.

**Your behavior**  
Emit row for A immediately. Later emit an updated row for B (possible second-row penalty). `finalize` is always `[]`.

**Gold behavior**  
Hold both in memory. Emit **one** final row for that key only in `finalize`.

**Why it matters**  
A sample/harness that only inspects `finalize` sees nothing from you. Early emit can also produce a second row for the same key (−2 points each). You already lost 28 points this way (14 extra rows).

**What to change**  
Never `return [row]` from `process`. Collect everything; emit once in `finalize`.

---

## 2. Job-close / incomplete outputs

**Your code**  
No special path — same as normal records. Incomplete lines without a title fail `check_quality` (L226–243) and drop.

**Gold code**
```python
# L592–622 _process_record (sketch)
if job and not complete:
    pending.append(rec)
elif closing:
    for output in pending:
        self._accept(_inherit(output, context))
```

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

**Your code**
```python
# L26–56 extract_json_payload
json.loads(...)
# or slice between first { and last }
# then one-level unwrap of message/data/payload
```

**Gold code**
```python
# L30–152 _LooseJSON + L154–211 _parse
# tolerates logger prefix, unescaped quotes,
# comments, truncated objects, recursive unwrap
```

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

**Your code**
```python
# L59–76 KEY_ALIASES + L79–97 normalize_keys
# flat alias map only; no deep walk
```

**Gold code**
```python
# L213–248 _flatten + L250–281 _expand
# recursive containers + list-of-renditions
```

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

## 5. Rendition

**Your code**
```python
# L106–142 normalize_rendition
# Np regex or width→height map
```

**Gold code**
```python
# L284–338 _rendition_text / _rendition
# + 4k/uhd/fhd, WxH, nested labels
```

**Example input**  
`"variant": "1920x1080"` or `"4k"`

**Your behavior**  
Rendition null → row dropped.

**Gold behavior**  
Maps to `1080p` / `2160p`.

**Why it matters**  
“Rung as size/name/number” is a noticeable recovery gap.

**What to change**  
Add nickname aliases and dimension parsing.

---

## 6. Codec

**Your code**
```python
# L144–154 normalize_codec
CODEC_ALIASES = {"264": "h264", "hevc": "h265", ...}
```

**Gold code**
```python
# L341–360 _codec_text
# avc1.…, hev1.…, libx264, av01.… etc.
```

**Example input**  
`"codec": "avc1.640028"`

**Your behavior**  
Codec null.

**Gold behavior**  
`h264`.

**Why it matters**  
Codec strings vary by toolchain.

**What to change**  
Expand the alias / pattern set.

---

## 7. Bitrate & duration

**Your code**
```python
# L156–185
# simple number + min/h multipliers
```

**Gold code**
```python
# L393–461 _bitrate / _duration
# Decimal, many units, sentinel rejection
```

**Example input**  
`"bitrate": "5 Mbps"` or `"duration": -1`

**Your behavior**  
May mis-scale or keep a sentinel value.

**Gold behavior**  
5000 kbps / null.

**Why it matters**  
Unit drift and sentinels (0 / −1 / NaN) cost cells.

**What to change**  
Use Decimal + broader unit table; treat sentinels as null when appropriate.

---

## 8. Dedup / same-timestamp fill

**Your code**
```python
# L275–281
if existing and row["packaged_at"] <= existing["packaged_at"]:
    return []
self.records[key] = row
return [row]
```

**Gold code**
```python
# L570–590 _accept
# newer instant wins;
# same instant → fill nulls, mark conflicts
```

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
