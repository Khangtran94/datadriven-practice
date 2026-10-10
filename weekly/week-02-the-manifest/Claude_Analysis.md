# Week 2: The Manifest: `handler.py` vs `gold_submit.py`

**Your score:** 0.8266 · **Rank:** #3 of 9 (top 33%) · **Points:** +120
**Records recovered:** 806,315 of 928,817 · **Work per record:** 2.1x median · **Statements:** 178
**Context:** a packager feed logs 1 JSON line per video rendition, and the delivery team needs 1 clean row per `(title_id, rendition)`: `title_id, rendition, codec, bitrate_kbps, duration_s, packaged_at`. The newest package run wins.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

---

## Impact ranking

| # | Area | Evidence from README | Gap vs gold |
|---|---|---|---|
| 1 | Rendition (rung) parsing | 6.0% of stream, 27% recovered; `rendition` missed 122,502 | No `WxH`, nicknames or labels; key-order-dependent width/height |
| 2 | Nesting and job close lines | 4.0% (28%) and 2.5% (1%) | No flattening; outputs without a title are dropped |
| 3 | Bitrate units | `bitrate_kbps` wrong 50,848, missed 133,386 | First digits only, units ignored, NaN drops the row |
| 4 | Duration formats | `duration_s` wrong 38,400, missed 120,573 | Timecodes and ISO read as the first number |
| 5 | Timestamps and the `packaged` gate | epoch 4.0% (53%), dates 4.0% (53%); `packaged_at` missed 119,970 | Milliseconds and slash dates fail, and failure drops the row |
| 6 | JSON recovery | broken 3.0% (36%), truncated 0.5% (1%) | Strict parser plus one brace slice |
| 7 | Codec tags | `codec` missed 161,388, wrong 1,023 | No RFC 6381 or library names; guessed digits |
| 8 | Emit timing and re-delivery | 14 second rows = 28 points | Emits on first sight and again on newer |

---

## 1. Rendition (rung) parsing

**Your code**
```python
# L61: "variant": [..., "height", "width"]  -> first non-null in dict order wins
# L106–142 normalize_rendition: only "720p", bare height, or bare width
match = re.fullmatch(r"(\d+)\s*p", value)
match = re.fullmatch(r"(\d+)\s*(?:w|wide|width)?", value)
# L239–240: check_quality drops the row if rendition is None
```

**Gold code**
```python
# L283–308 _rendition_text: aliases, WxH, labels
aliases = {'4k': '2160p', 'uhd': '2160p', 'fullhd': '1080p', 'fhd': '1080p', 'hd': '720p'}
dimensions = re.fullmatch(r'(\d{3,4})\s*x\s*\d{2,4}(?:\s*[pi])?', value)   # width wins
# L311–337 _rendition: variant keys first, then width, then height
```

**Example input**
- `"resolution": "1920x1080"`
- `"variant": "FHD"`
- `"width": 1920, "height": 800` (a scope title, wider than 16:9)
- `"variant": "video_1080p_h264"`

**Your behavior**
- `"1920x1080"` and `"FHD"` match neither regex, so the rendition is `None` and `check_quality` drops the row.
- With both `width` and `height` present, whichever key appears first in the line wins, and key order is arbitrary (30% of the stream). Height 800 gives `None`; width 1920 gives `1080p`.
- The label returns `None`.

**Gold behavior**
`1080p` for all four. Width wins for dimensions, including letterboxed encodes. Nicknames and labels are resolved, and `427`/`853` are accepted as widths.

**Why it matters**
`title_id` and `rendition` are the identity key, so each miss loses the whole row (122,502 missed on both columns).

**What to change**
Prefer width over height (README: scope titles are wider than 16:9, so the rung is read from the width). Add `WxH`, nicknames, label extraction and dict values like `{width, height}`.

---

## 2. Nesting and job close lines

**Your code**
```python
# L79–97 normalize_keys: top-level keys only
# L26–56 extract_json_payload: unwraps one logger field (message/data/payload/...)
# L237–238: check_quality requires title_id
```

**Gold code**
```python
# L213–247 _flatten: containers (payload, data, video, media, encoding, ...), asset/title dicts, job dicts
# L250–273 _expand: one line with a list of outputs becomes many records
# L528–562, L592–618: jobs held as context + pending outputs, resolved at the close line
# L633–640 finalize flushes still-open jobs
```

**Example input**
- Nested: `{"asset":{"id":"T-0000001","duration":5400},"video":{"variant":"720p","codec":"hevc","bitrate":3000},"packaged_at":"2026-01-02T10:00:00Z"}`
- Job output (no title): `{"job_id":"J-9","variant":"720p","codec":"h264","bitrate":3000,"packaged":"2026-01-02T10:00:00Z"}`
- Later close line: `{"job_id":"J-9","event":"close","title_id":"T-0000001","duration":5400}`

**Your behavior**
- The nested line exposes no recognized top-level key except `packaged_at`, so there is no title and the row is dropped.
- The job output has no title, so it is dropped.
- The close line has no rendition, so it is dropped too.

**Gold behavior**
It flattens `video` and `asset` and keeps the id and duration. Job outputs wait as pending until the close line arrives, then inherit its title and duration. Any still-pending job is flushed in `finalize`.

**Why it matters**
Nesting is 4.0% of the stream (28% recovered) and job close lines 2.5% (1% recovered). Together they are the biggest structural gap.

**What to change**
Flatten nested dicts into one namespace (first non-null wins). Buffer job outputs by `job_id` and fill title and duration from the close line.

---

## 3. Bitrate units

**Your code**
```python
# L156–165
if isinstance(bitrate, (int,float)):
    return int(bitrate)
...
match = re.search(r"\d+", bitrate)
return int(match.group())
```
The alias list (L63) has no `bandwidth` or `bitrate_bps` keys.

**Gold code**
```python
# L393–423 _bitrate: unit table (kbps=1, mbps=1000, bps=0.001, bytes ×8), key-implied units
# L401: number < 0 or non-finite -> None
# L422: "Whole kbps only: no undocumented rounding or magnitude-based unit guesses."
```

**Example input**
`"bitrate":"4.5 Mbps"`, `"bitrate":"4500000 bps"`, `"bandwidth":"4500000"`, `"bitrate":-1`, `"bitrate":NaN`

**Your behavior**
- `"4.5 Mbps"` gives `4` (first digits only).
- `"4500000 bps"` gives `4500000`; the unit is ignored, so it is bits per second read as kbps.
- `bandwidth` is not an alias, so `None`.
- `-1` is kept as -1.
- JSON `NaN` loads as a float, and `int(nan)` raises `ValueError`. The `except` at L283 returns `[]`, so the whole row is lost.

**Gold behavior**
`4500`, `4500`, `4500` (key-implied bps), `None`, `None`. It rejects negatives and non-finite values and keeps only whole kbps. It does keep 0, though the README calls 0 a sentinel, so test nulling it. A bare number under a plain `bitrate` key is taken as kbps whatever its size.

**Why it matters**
`bitrate_kbps` is wrong 50,848 times, the largest wrong count of the week.

**What to change**
Read the unit from the value, a sibling `unit`, or the key name, then convert to kbps. Reject negatives, zero and NaN. Do not take the first digits of a string. Beyond gold: the README says a rendition is never 6 kbps, so the magnitude of a bare number can say which unit it is in. Gold refuses to guess that.

---

## 4. Duration formats

**Your code**
```python
# L167–185
match = re.search(r"(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)?", duration.lower())
```
The alias list (L64) has no `duration_ms`.

**Gold code**
```python
# L426–460 _duration
clock = re.fullmatch(r'(?:(\d+):)?(\d{1,2}):(\d{2}(?:\.\d+)?)', text)        # 01:30:00
iso   = re.fullmatch(r'PT(?:(\d+(?:\.\d+)?)H)?(?:...M)?(?:...S)?', text, re.I)  # PT1H30M
# unit factors s / ms / us / min / h; key-implied ms and us; negatives -> None
```

**Example input**
`"duration":"01:30:00"`, `"duration":"PT1H30M"`, `"duration_ms":5400000`, `"duration":"90 min"`, `"duration":-1`

**Your behavior**
- `"01:30:00"` reads `01` as 1.0 seconds.
- `"PT1H30M"` matches `1` + `h` and returns 3600.0, ignoring the 30 minutes.
- `duration_ms` is not an alias, so `None`.
- `"90 min"` gives 5400.0, which is correct.
- `-1` stays -1.0.

**Gold behavior**
5400.000 for the first four, `None` for -1.

**Why it matters**
`duration_s` is wrong 38,400 times and missed 120,573.

**What to change**
Parse timecodes and ISO durations before any generic number match. Add the `duration_ms`/`duration_us` keys. Reject negatives and NaN.

---

## 5. Timestamps and the `packaged` gate

**Your code**
```python
# L187–223 normalize_packaged: epoch seconds only; fromisoformat otherwise
dt = datetime.fromtimestamp(float(packaged), tz=timezone.utc)   # ms -> ValueError -> None
# L241–242
if normalize_packaged(rec.get("packaged")) is None:
    return False
```

**Gold code**
```python
# L463–498 _timestamp: ms / µs / ns by magnitude, "UTC"/"GMT" suffix, year-first slash dates, {"$date": ...}
# L520–525: a row with an unparsable time is still emitted (packaged_at None)
# L570–590 _accept: timed rows beat untimed; same-instant ties fill holes
```

**Example input**
`"packaged": 1767348000000` (ms), `"packaged": "2026/01/02 10:00:00"`, `"packaged": "2026-01-02 10:00:00 UTC"`, `"packaged": null`

**Your behavior**
All four return `None` from `normalize_packaged`, and `check_quality` drops the whole row.

**Gold behavior**
The first three parse to `2026-01-02T10:00:00Z`. The null row is kept with `packaged_at = None`.

**Why it matters**
`packaged_at` missed 119,970, almost the same as the 122,502 missed on the identity columns. The time gate removes rows that could still earn `title_id` and `rendition` credit.

**What to change**
Parse epochs by magnitude and add slash dates and `UTC`/`GMT` suffixes. Do not require a time to keep a row; use it only to choose the newest.

---

## 6. JSON recovery

**Your code**
```python
# L26–56: whole line, or text[first "{" : last "}"], strict json.loads, dict only
```

**Gold code**
```python
# L154–185 _parse: strip BOM/NUL, json.loads(strict=False), raw_decode from each "{"/"[", double-decode
# L30–151 _LooseJSON: unquoted keys, single quotes, comments, truncated objects keep complete fields
```

**Example input**
- `2026-01-02T10:00:00Z INFO {"title_id":"T-0000001","variant":"720p",}`
- A string value containing a literal tab
- `{"title_id":"T-0000001","variant":"720p","codec":"h26` (truncated)

**Your behavior**
All three raise inside `json.loads` and the line is dropped.

**Gold behavior**
All three yield a record. The truncated one keeps its completed fields.

**Why it matters**
Broken JSON is 3.0% of the stream (36% recovered) and truncated lines 0.5% (1%).

**What to change**
Use `strict=False` and `raw_decode` from the first `{`. Add a small fallback that keeps complete fields of a truncated object.

---

## 7. Codec tags

**Your code**
```python
# L9
CODEC_ALIASES = {"264":"h264","h264":"h264","avc":"h264","265":"h265",... "1":"av1","9":"vp9"}
# L144–154: exact lookup after lowercase
```

**Gold code**
```python
# L340–365
'avc1': 'h264', 'x264': 'h264', 'libx264': 'h264', 'hvc1': 'h265', 'libx265': 'h265',
'av01': 'av1', 'libsvtav1': 'av1', 'vp09': 'vp9', 'libvpxvp9': 'vp9'
re.fullmatch(r'(avc1|avc3)\.[0-9a-f]{6}', value)    # RFC 6381 tags
```

**Example input**
`"codec":"avc1.64001f"`, `"codec":"hev1.1.6.L93.B0"`, `"codec":"libx265"`, `"codec":"1"`, `"codec":"prores"`

**Your behavior**
- The first three return `None`.
- `"1"` becomes `av1`, a guess.
- `"prores"` is `None`, which is correct.

**Gold behavior**
`h264`, `h265`, `h265`, `None`, `None`. It does not map bare digits.

**Why it matters**
`codec` missed 161,388 and was wrong 1,023 times; the guessed digits may account for some of the wrong values.

**What to change**
Normalize by removing separators, then match aliases and RFC 6381 prefixes. Drop the bare-digit guesses.

---

## 8. Emit timing and re-delivery

**Your code**
```python
# L275–282
existing = self.records.get(key)
if existing is not None and row['packaged_at'] <= existing['packaged_at']:
    return []
self.records[key] = row
return [row]
# L286–287
def finalize(self): return []
```

**Gold code**
```python
# L620–631 process: only merge into self.held, return []
# L570–590 _accept: newest instant wins; same-instant conflicts become None
# L633–648 finalize: flush pending jobs, then emit one row per key
```

**Example input**
The same key arrives first as an old run (10:00) and later as a newer run (11:00).

**Your behavior**
Both are emitted. The old run goes out on first sight and the newer run goes out again, so the key has two rows.

**Gold behavior**
Nothing is emitted in `process`. `finalize` writes the newest row once.

**Why it matters**
14 second rows cost 28 points. That is small today, but emit-on-first-sight can never retract a row, and it blocks the job-close inheritance in section 2.

**What to change**
Buffer by `(title_id, rendition)`. Keep the newest `packaged_at`, tie-break by filling holes, and emit in `finalize`.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}                            # (title_id, rendition) -> (instant, row)
        self.jobs = {}                            # job_id -> (context, pending outputs)

    def process(self, raw):
        for rec in expand(parse(raw)):            # strict=False, raw_decode, flatten, split output lists
            job = job_id(rec)
            if job is None:
                self.accept(rec)                  # newest packaged instant wins; ties fill holes
            else:
                self.add_to_job(job, rec)         # pending until the close line supplies title/duration
        return []                                 # never emit here

    def finalize(self):
        self.flush_open_jobs()                    # resolve pending outputs with the context seen so far
        return [row_dict(r) for r in self.held.values()]   # exactly one row per key
```
