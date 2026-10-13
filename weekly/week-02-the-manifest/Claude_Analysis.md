# Week 2: The Manifest: `handler.py` vs `gold_submit.py`

**Your score:** 0.8266 · **Rank:** #3 of 9 (top 33%) · **Points:** +120
**Records recovered:** 806,315 of 928,817 · **Work per record:** 2.1x median · **Statements:** 178
**Context:** a packager feed logs 1 JSON line per video rendition, and the delivery team needs 1 clean row per `(title_id, rendition)`: `title_id, rendition, codec, bitrate_kbps, duration_s, packaged_at`. The newest package run wins.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

**Evidence tags:** `[measured]` from the README · `[estimate]` from my local run of your handler, the gold file and the proposed handler on hand-built inputs (not the real feed) · `[inferred]` from reading the code · `[untested]` proposed code I could not run.

> **How this file works.** Every section shows your code verbatim (**Before**), the proposed code (**After**), a plain-language **How it works**, and a **Proof** table where I ran your handler, the gold file and the proposed handler on the same input. The complete proposed handler is at the end.

> **A note on the gold file.** The repo's `gold_submit.py` ends without a `return rows` in `Handler.finalize` (the last lines repeat the loop that builds `rows`), so as it sits in the repo `finalize()` returns `None`. To test gold's logic I ran a copy with that one line added. The numbers below are for that copy.

## Proof summary `[estimate]`

- 36 hand-built scenarios (one or more per section below): **your handler passes 5, gold passes 33, the proposed handler passes 36.** I wrote the scenarios and the proposed handler together, so treat this as a check of the ideas, not a score prediction.
- On a clean stream of 18,000 lines (16,000 unique plus 2,000 exact re-sends), your handler, gold and the proposed handler returned **identical final rows**, so the changes only affect the problem cases.
- Gold misses three of my scenarios: `duration: 0` (it keeps 0, while the README calls 0 a sentinel) and two truncated lines.

---

## Impact ranking

| # | Area | Evidence from README | Gap vs gold |
|---|---|---|---|
| 1 | Rendition (rung) parsing | 6.0% of stream, 27% recovered; `rendition` missed 122,502 `[measured]` | No `WxH`, nicknames or labels; width/height depends on key order |
| 2 | Nesting and job close lines | 4.0% (28%) and 2.5% (1%) | No flattening; outputs without a title are dropped |
| 3 | Bitrate units | `bitrate_kbps` wrong 50,848, missed 133,386 | First digits only, units ignored, NaN drops the row |
| 4 | Duration formats | `duration_s` wrong 38,400, missed 120,573 | Timecodes and ISO read as the first number |
| 5 | Timestamps and the `packaged` gate | epoch 4.0% (53%), dates 4.0% (53%); `packaged_at` missed 119,970 | Milliseconds and slash dates fail, and failure drops the row |
| 6 | JSON recovery | broken 3.0% (36%), truncated 0.5% (1%) | Strict parser plus one brace slice |
| 7 | Codec tags | `codec` missed 161,388, wrong 1,023 | No RFC 6381 or library names; guessed digits |
| 8 | Emit timing and re-delivery | 14 second rows = 28 points | Emits on first sight and again on newer |

---

## 1. Rendition (rung) parsing

**Your code**: the `variant` aliases include `height` and `width`, and the first non-null in line order wins. `normalize_rendition` understands `720p`, a bare height or a bare width. A row without a rendition is dropped by `check_quality`.

**Gold code**: `gold_submit.py` L284–340 (`_rendition_text`, `_rendition`): nicknames, `WxH` (width wins), labels, objects with width and height, then width keys before height keys.

**Example input**: `"variant":"1920x1080"`; `"variant":"FHD"`; `"width":1920,"height":800` (a scope title, wider than 16:9) with the keys in either order; `"variant":"video_1080p_h264"`; `"variant":{"width":1920,"height":1080}`.

**Your behavior**: `1920x1080`, `FHD`, the label and the object all give no rung, so the row is dropped. With `width` before `height` it works (width wins); with `height` listed first the height 800 wins and the row is dropped. Key order is arbitrary in 30% of the stream.

**Gold behavior**: `1080p` for all of them.

**Why it matters**: `title_id` and `rendition` form the identity key, so each miss loses the whole row (122,502 missed on both columns) `[measured]`. Rung as size, name or number is 6.0% of the stream with 27% recovered.

**Before** (`handler.py`)
```python
  7  WIDTH_TO_RENDITION = {426: "240p",640: "360p",854: "480p",1280: "720p",1920: "1080p",3840: "2160p"}
...
106  def normalize_rendition(variant):
107      """
108      Normalize a variant value into a rendition string.
109      Examples:
110          240       -> "240p"
111          "240"     -> "240p"
112          "720P"    -> "720p"
113          "720p"    -> "720p"
114          1920      -> "1080p"
115          "1920w"   -> "1080p"
116          "1920 w"  -> "1080p"
117          "1920 wide" -> "1080p"
118      Returns:
119          str | None: normalized rendition, or None if invalid.
120      """
121      if variant is None:
122          return None
123      value = str(variant).strip().lower()
124      # Already has "p": 240p, 720P, 1080 p
125      match = re.fullmatch(r"(\d+)\s*p", value)
126      if match:
127          rendition = f"{match.group(1)}p"
128          return rendition if rendition in VALID_RENDITIONS else None  
129      # Width with optional "w" / "wide" / "width":
130      match = re.fullmatch(r"(\d+)\s*(?:w|wide|width)?", value)
131      if not match:
132          return None
133      number = int(match.group(1))
134      # Case 1: number is directly a valid rendition
135      rendition = f"{number}p"
136      if rendition in VALID_RENDITIONS:
137          return rendition
138      # Case 2: number is a known video width
139      if number in WIDTH_TO_RENDITION:
140          return WIDTH_TO_RENDITION[number]
141      # Case 3: number is neither
142      return None
```

**After**
```python
RUNGS = {240, 360, 480, 720, 1080, 2160}

WIDTH_TO_RUNG = {426: 240, 427: 240, 640: 360, 854: 480, 853: 480, 1280: 720, 1920: 1080, 3840: 2160}

NICKNAMES = {"4k": "2160p", "uhd": "2160p", "fullhd": "1080p", "fhd": "1080p", "hd": "720p"}

def rung_from_text(t):
    s = re.sub(r"\s+", "", str(t).lower())
    if s in NICKNAMES:
        return NICKNAMES[s]
    m = re.fullmatch(r"(\d{3,4})x(\d{3,4})p?", s)        # 1920x1080: the WIDTH names the rung (scope titles are wider)
    if m:
        r = WIDTH_TO_RUNG.get(int(m.group(1)))
        return f"{r}p" if r else None
    m = re.search(r"(?<!\d)(\d{3,4})p", s)               # 720p, video_1080p_h264
    if m and int(m.group(1)) in RUNGS:
        return f"{int(m.group(1))}p"
    m = re.fullmatch(r"(\d{3,4})(w|wide|width)?", s)
    if m:
        n = int(m.group(1))
        if not m.group(2) and n in RUNGS:
            return f"{n}p"
        r = WIDTH_TO_RUNG.get(n)
        return f"{r}p" if r else None
    return None

def clean_rendition(c):
    v = c.get("variant", (None, None))[0]
    if isinstance(v, dict):                              # {"width": 1920, "height": 1080}
        w = next((x for k, x in v.items() if norm_key(k) in ALIASES["width"] and not is_null(x)), None)
        v = f"{w}w" if w is not None else None
    r = rung_from_text(v) if v is not None else None
    if r is None and "width" in c:
        r = rung_from_text(f"{c['width'][0]}w")
    if r is None and "height" in c and "variant" not in c:
        r = rung_from_text(c["height"][0])
    return r
```

**How it works**: the rung is read from the width whenever a width is present, so letterboxed encodes such as 1920×800 still map to `1080p`, whatever order the keys came in. Text is recognized as a nickname (`FHD`, `4K`), `WxH`, a label containing `NNNNp`, or a bare number.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| rung: '1920x1080' | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| rung: nickname 'FHD' | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| rung: width 1920, height 800 (scope) | `4500` | ✔ 4500 | ✔ 4500 | ✔ 4500 |
| rung: same, height listed first | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| rung: label 'video_1080p_h264' | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| rung: object {width,height} | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |

---

## 2. Nesting and job close lines

**Your code**: `normalize_keys` reads top-level keys only, `extract_json_payload` unwraps one logger field, and `check_quality` requires a title, a rendition and a time on every line.

**Gold code**: `gold_submit.py` L213–275 (`_flatten`, `_expand`), L528–562 (`_job_id`, `_closed`, `_inherit`), L592–618: sub-objects are flattened, a list of outputs becomes several records, and outputs without a title wait for the job's close line.

**Example input**
- Nested: `{"asset":{"title_id":"T-0000007","duration":5400},"video":{"variant":"720p","codec":"hevc","bitrate":3000},"packaged_at":"..."}`
- A job output with no title, then its close line: `{"job_id":"J-9","variant":"720p",...}` followed by `{"job_id":"J-9","event":"close","title_id":"T-0000008","duration":5400}`

**Your behavior**: the nested line shows no recognized key at the top level, so there is no title and the row is dropped. The job output has no title (dropped), and the close line has no rendition (dropped).

**Gold behavior**: one row each, with the title and the duration taken from the close line.

**Why it matters**: nesting is 4.0% of the stream (28% recovered) and job close lines 2.5% (1% recovered) `[measured]`, together the biggest structural gap.

**Before** (`handler.py`)
```python
 79  def normalize_keys(rec):
 80      """
 81      Map an incoming record's arbitrary key names onto the canonical
 82      keys clean() expects (title_id, variant, codec, bitrate, duration, packaged).
 83   
 84      If two raw keys map to the same canonical field, the first non-null
 85      value wins and later ones are ignored (order = dict iteration order).
 86      Unrecognized keys are dropped silently.
 87      """
 88      if not isinstance(rec, dict):
 89          return {}
 90      out = {}
 91      for raw_key, value in rec.items():
 92          canonical = _ALIAS_LOOKUP.get(_normalize_key_name(raw_key))
 93          if canonical is None:
 94              continue
 95          if out.get(canonical) is None:
 96              out[canonical] = value
 97      return out
...
237      if parse_title_id(rec.get("title_id")) is None:
238          return False
```

**After**
```python
def flatten(obj, depth=0):
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat

def expand(rec):                                         # one line may carry a list of outputs
    for k in LISTS:
        if isinstance(rec.get(k), list) and rec[k] and all(isinstance(x, dict) for x in rec[k]):
            base = {a: b for a, b in rec.items() if a != k}
            return [{**base, **x} for x in rec[k]]
    return [rec]

def canonical(rec):                                      # field -> (value, original key); null spellings never take a slot
    out = {}
    for k, v in flatten(rec).items():
        f = LOOKUP.get(norm_key(k))
        if f and f not in out and not is_null(v):
            out[f] = (v, k)
    return out

def is_close(rec):
    for k in ("event", "eventtype", "type", "kind", "status", "state", "action"):
        v = rec.get(k)
        if isinstance(v, str) and norm_key(v) in CLOSE_WORDS:
            return True
    return False

def job_id(c):
    v = c.get("job", (None,))[0]
    return str(v).strip() or None if isinstance(v, (str, int)) and not isinstance(v, bool) else None


class Handler:                                           # excerpt: the process() method
    def process(self, raw):
        try:
            rec = parse_raw(raw)
            for r in (expand(rec) if rec else []):
                c = canonical(r)
                job = job_id(c)
                title = clean_title(c["title"][0]) if "title" in c else None
                rendition = clean_rendition(c)
                if job is None:
                    if title and rendition:
                        self._accept(title, rendition, c)
                    continue
                ctx = self.jobs.setdefault(job, {"title": None, "duration": None, "pending": []})
                if is_close(r) or rendition is None:     # a close line names the job's title but no rendition
                    ctx["title"] = title or ctx["title"]
                    ctx["duration"] = c.get("duration") or ctx["duration"]
                    if ctx["title"]:
                        for pc, pr in ctx["pending"]:
                            self._accept(ctx["title"], pr, pc, ctx)
                        ctx["pending"] = []
                    continue
                title = title or ctx["title"]
                if title:
                    self._accept(title, rendition, c, ctx)
                else:
                    ctx["pending"].append((c, rendition))   # output logged before its close line
        except Exception:
            pass
        return []
```

**How it works**: nested sub-objects are flattened into one dictionary, with top-level keys winning. Each field is looked up by normalized key name, skipping null spellings. A line with a job id and a title goes straight to the table. A line with a job id and no title waits in that job's list; the job's close line (no rendition, or an `event` such as `close`) supplies the title and the duration and releases the waiting outputs.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| nested: asset / video sub-objects | `h265` | ✘ <no row> | ✔ h265 | ✔ h265 |
| job: output line then close line (duration) | `5400.0` | ✘ <no row> | ✔ 5400.0 | ✔ 5400.0 |
| job: output line then close line (title) | `3000` | ✘ <no row> | ✔ 3000 | ✔ 3000 |

---

## 3. Bitrate units

**Your code**: `re.search(r"\d+")` takes the first run of digits and ignores units; there are no `bandwidth` or `bps` keys.

**Gold code**: `gold_submit.py` L368–425 (`_decimal_unit`, `_bitrate`): a unit table (bps, kbps, Mbps), units implied by the key name, negatives and non-finite values rejected, whole kbps only. A bare number under a plain `bitrate` key is read as kbps whatever its size.

**Example input**: `"bitrate":"4.5 Mbps"`; `"bitrate":"4500000 bps"`; `"bandwidth":"4500000"`; `"bitrate":-1`; `"bitrate":NaN`.

**Your behavior**: `4.5 Mbps` gives `4`; `4500000 bps` gives `4500000`; `bandwidth` is not an alias (`None`); `-1` is kept; and a JSON `NaN` makes `int(nan)` raise, which sends the whole row to the `except` at L283 and drops it.

**Gold behavior**: `4500`, `4500`, `4500`, `None`, `None`.

**Why it matters**: `bitrate_kbps` was wrong 50,848 times and missed 133,386, the largest wrong count of the week `[measured]`.

**Before** (`handler.py` L156–165)
```python
156  def normalize_bitrate(bitrate):
157      if bitrate is None:
158          return None
159      if isinstance(bitrate, (int,float)):
160          return int(bitrate)
161      if isinstance(bitrate, str):
162          match = re.search(r"\d+", bitrate)
163          if match:
164              return int(match.group())
165      return None
```

**After**
```python
def _number(text):
    s = text.strip()
    if "," in s and "." in s:
        s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", "") if re.fullmatch(r"\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
    return Decimal(s)

KBPS = {"bps": Decimal("0.001"), "b/s": Decimal("0.001"), "kbps": Decimal(1), "kb/s": Decimal(1), "k": Decimal(1),
        "mbps": Decimal(1000), "mb/s": Decimal(1000), "m": Decimal(1000), "gbps": Decimal(10**6)}

def clean_bitrate(v, key):                               # whole kbps, or None
    try:
        if isinstance(v, bool):
            return None
        unit = None
        if isinstance(v, str):
            m = re.fullmatch(r"\s*([\d.,]+)\s*([A-Za-z/]*)\s*", v)
            if not m:
                return None
            d, unit = _number(m.group(1)), m.group(2).lower() or None
        else:
            d = Decimal(str(v))
        nk = norm_key(key)
        unit = unit or ("mbps" if nk.endswith("mbps") else "kbps" if nk.endswith("kbps") else
                        "bps" if nk.endswith("bps") or nk == "bandwidth" else "kbps")
        if unit not in KBPS:
            return None
        kbps = d * KBPS[unit]
        if not kbps.is_finite() or kbps <= 0 or kbps != kbps.to_integral_value():
            return None
        return int(kbps)
    except (InvalidOperation, ValueError):
        return None
```

**How it works**: the unit comes from the text (`Mbps`, `bps`), or from the key name, and the value is converted to kilobits per second. Only positive, finite, whole numbers are accepted; everything else is null instead of a guess.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| bitrate: '4.5 Mbps' | `4500` | ✘ 4 | ✔ 4500 | ✔ 4500 |
| bitrate: '4500000 bps' | `4500` | ✘ 4500000 | ✔ 4500 | ✔ 4500 |
| bitrate: key 'bandwidth' = 4500000 | `4500` | ✘ None | ✔ 4500 | ✔ 4500 |
| bitrate: -1 (probe failed) | `None` | ✘ -1 | ✔ None | ✔ None |
| bitrate: NaN | `None` | ✘ <no row> | ✔ None | ✔ None |

> Beyond gold: the README says a rendition is never 6 kbps, so the size of a bare number could also reveal its unit. Gold refuses to guess that, and so does this version `[untested]`.

---

## 4. Duration formats

**Your code**: one regex takes the first number and an optional unit; there is no `duration_ms` key.

**Gold code**: `gold_submit.py` L426–462 (`_duration`): clock timecodes, ISO `PT...` durations, units, ms/µs keys, and negatives rejected (it keeps 0).

**Example input**: `"01:30:00"`; `"PT1H30M"`; key `duration_ms` = 5400000; `"90 min"`; `-1`; `0`.

**Your behavior**: `01:30:00` is read as 1.0 second; `PT1H30M` matches `1` and `h` and gives 3600.0, ignoring the 30 minutes; `duration_ms` is not an alias (`None`); `90 min` is correct; `-1` and `0` are kept as values.

**Gold behavior**: 5400.0 for the first four and `None` for `-1`; for `0` it returns `0.0`.

**Why it matters**: `duration_s` was wrong 38,400 times and missed 120,573 `[measured]`. The README calls 0 and -1 sentinels ("they are the absence of one"), so null is the safer answer for both.

**Before** (`handler.py` L167–185)
```python
167  def normalize_duration(duration):
168      if duration is None:
169          return None
170      if isinstance(duration, (int, float)):
171          return round(float(duration), 3)
172      if isinstance(duration, str):
173          match = re.search(
174              r"(\d+(?:\.\d+)?)\s*(seconds?|secs?|s|minutes?|mins?|m|hours?|hrs?|h)?",
175              duration.lower())
176          if not match:
177              return None
178          value = float(match.group(1))
179          unit = match.group(2)
180          if unit in {"minutes", "minute", "mins", "min", "m"}:
181              value *= 60
182          elif unit in {"hours", "hour", "hrs", "hr", "h"}:
183              value *= 3600
184          return round(value, 3)
185      return None
```

**After**
```python
DUR_UNITS = {"ms": 0.001, "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1, "m": 60, "min": 60, "mins": 60,
             "minute": 60, "minutes": 60, "h": 3600, "hr": 3600, "hrs": 3600, "hour": 3600, "hours": 3600}

def clean_duration(v, key):                              # seconds with 3 decimals, or None
    try:
        if isinstance(v, bool):
            return None
        secs = None
        if isinstance(v, str):
            s = v.strip()
            m = re.fullmatch(r"(?:(\d+):)?(\d{1,2}):(\d{2}(?:\.\d+)?)", s)          # 01:30:00  or  90:00
            iso = re.fullmatch(r"PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?", s, re.I)
            u = re.fullmatch(r"(\d+(?:\.\d+)?)\s*([A-Za-z]+)", s)
            if m:
                secs = int(m.group(1) or 0) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
            elif iso and any(iso.groups()):
                secs = sum(float(x or 0) * f for x, f in zip(iso.groups(), (3600, 60, 1)))
            elif u and u.group(2).lower() in DUR_UNITS:
                secs = float(u.group(1)) * DUR_UNITS[u.group(2).lower()]
            else:
                v = float(_number(s))
        if secs is None:
            nk = norm_key(key)
            secs = float(v) * (0.001 if nk.endswith("ms") else 60 if nk.endswith("min") else 1)
        return round(secs, 3) if math.isfinite(secs) and secs > 0 else None      # 0, -1, NaN are "no value"
    except (ValueError, InvalidOperation, OverflowError):
        return None
```

**How it works**: timecodes and ISO durations are recognized before any generic number match; a key ending in `ms` or `min` sets the unit; zero, negative and non-finite results are null.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| duration: '01:30:00' | `5400.0` | ✘ 1.0 | ✔ 5400.0 | ✔ 5400.0 |
| duration: ISO 'PT1H30M' | `5400.0` | ✘ 3600.0 | ✔ 5400.0 | ✔ 5400.0 |
| duration: key duration_ms = 5400000 | `5400.0` | ✘ None | ✔ 5400.0 | ✔ 5400.0 |
| duration: '90 min' | `5400.0` | ✔ 5400.0 | ✔ 5400.0 | ✔ 5400.0 |
| duration: -1 | `None` | ✘ -1.0 | ✔ None | ✔ None |
| duration: 0 | `None` | ✘ 0.0 | ✔ None | ✘ 0.0 |

---

## 5. Timestamps and the `packaged` gate

**Your code**: epoch seconds only, `fromisoformat` otherwise, and `check_quality` drops any row whose `packaged` time does not parse.

**Gold code**: `gold_submit.py` L463–500 (`_timestamp`: ms/µs/ns by size, `UTC`/`GMT` suffix, year-first slash dates), L509–525 (a row with an unparsable time is still emitted, with `packaged_at` null).

**Example input**: `"packaged": 1767348000000` (ms); `"2026/01/02 10:00:00"`; `"2026-01-02 10:00:00 UTC"`; `"packaged": null`.

**Your behavior**: all four give no time, and `check_quality` drops the whole row.

**Gold behavior**: the first three parse to `2026-01-02T10:00:00Z`; the null row is kept with `packaged_at = None`.

**Why it matters**: `packaged_at` was missed 119,970 times, almost the same as the 122,502 missed on the identity columns, so the time gate removes rows that could still earn credit `[measured]`. Epoch is 4.0% of the stream (53% recovered) and mixed dates 4.0% (53%).

**Before** (`handler.py` L187–223, L226–243)
```python
187  def normalize_packaged(packaged):
188      if packaged is None:
189          return None
190      if isinstance(packaged, bool):
191          return None
192      # Unix timestamp
193      if isinstance(packaged, (int, float)):
194          try:
195              dt = datetime.fromtimestamp(
196                  float(packaged),
197                  tz=timezone.utc)
198              return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
199          except (OSError, ValueError, OverflowError):
200              return None
201      if not isinstance(packaged, str):
202          return None
203      packaged = packaged.strip()
204      if not packaged:
205          return None
206      # NEW: nzumeric string -> treat as unix timestamp
207      try:
208          num = float(packaged)
209          dt = datetime.fromtimestamp(num, tz=timezone.utc)
210          return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
211      except (ValueError, OSError, OverflowError):
212          pass  # not a plain number, fall through to ISO parsing
213      # ISO 8601
214      try:
215          dt = datetime.fromisoformat(packaged)
216          # No timezone -> assume UTC
217          if dt.tzinfo is None:
218              dt = dt.replace(tzinfo=timezone.utc)
219          else:
220              dt = dt.astimezone(timezone.utc)
221          return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
222      except ValueError:
223          return None
...
226  def check_quality(rec):
227      """
228      A row is only worth keeping if we can determine its identity
229      (title_id + rendition — that's the dedupe key) and compare it for
230      recency (packaged_at). codec/bitrate/duration are NOT gated here:
231      a genuine null on one of those is free/correct, so dropping an
232      otherwise-identifiable row over one soft field only loses credit
233      for the fields that *did* parse, for no benefit.
234      """
235      if not isinstance(rec, dict) or not rec:
236          return False
237      if parse_title_id(rec.get("title_id")) is None:
238          return False
239      if normalize_rendition(rec.get("variant")) is None:
240          return False
241      if normalize_packaged(rec.get("packaged")) is None:
242          return False
243      return True
```

**After**
```python
TIME_RE = re.compile(r"(\d{4})[-/](\d{2})[-/](\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?)?\s*(Z|UTC|GMT|[+-]\d{2}:?\d{2})?", re.I)

def clean_time(v):                                       # aware UTC datetime, or None
    try:
        if isinstance(v, bool):
            return None
        if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
            v = float(v)
        if isinstance(v, (int, float)):
            n = float(v)
            n = n / 1e9 if n >= 1e17 else n / 1e6 if n >= 1e14 else n / 1e3 if n >= 1e11 else n
            return datetime.fromtimestamp(n, tz=timezone.utc)
        m = TIME_RE.fullmatch(str(v).strip())
        if not m:
            return None
        y, mo, d, hh, mm, ss, tz = m.groups()
        dt = datetime(int(y), int(mo), int(d), int(hh or 0), int(mm or 0), int(ss or 0), tzinfo=timezone.utc)
        if tz and tz.upper() not in ("Z", "UTC", "GMT"):
            sign = 1 if tz[0] == "+" else -1
            digits = tz[1:].replace(":", "")
            dt = dt - sign * timedelta(hours=int(digits[:2]), minutes=int(digits[2:]))
        return dt
    except (ValueError, OverflowError, OSError):
        return None
```

**How it works**: numbers are read by size (seconds, ms, µs, ns), and text with slashes, a `UTC` suffix or an offset is accepted. A missing time no longer drops the row; it only means the row cannot beat one that has a time (section 8).

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| time: epoch milliseconds | `2026-01-02T10:00:00Z` | ✘ <no row> | ✔ 2026-01-02T10:00:00Z | ✔ 2026-01-02T10:00:00Z |
| time: '2026/01/02 10:00:00' | `2026-01-02T10:00:00Z` | ✘ <no row> | ✔ 2026-01-02T10:00:00Z | ✔ 2026-01-02T10:00:00Z |
| time: '2026-01-02 10:00:00 UTC' | `2026-01-02T10:00:00Z` | ✘ <no row> | ✔ 2026-01-02T10:00:00Z | ✔ 2026-01-02T10:00:00Z |
| time: null (row still kept) | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |

---

## 6. JSON recovery

**Your code**: the whole line, or the text between the first `{` and the last `}`, with strict `json.loads`, dict only.

**Gold code**: `gold_submit.py` L154–204 (`_parse`: strip BOM and NUL, `strict=False`, `raw_decode` from each brace, decode again if the result is a string) and L30–152 (`_LooseJSON`, a tolerant parser).

**Example input**: `2026-01-02T10:00:00Z INFO {...,}` (log prefix and trailing comma); a string value with a literal tab; a line cut off in the middle (`...,"bitrate": 4500, "dur`).

**Your behavior**: all three raise inside `json.loads` and the line is dropped.

**Gold behavior**: the first two are recovered. On my two truncated lines gold returned no row, so it does not salvage them in these cases (the comparison is on those inputs only).

**Why it matters**: broken JSON is 3.0% of the stream (36% recovered) and truncated lines 0.5% (1%) `[measured]`. The README says everything before the cut is real.

**Before** (`handler.py` L26–56)
```python
 26  def extract_json_payload(raw):
 27      """
 28      Pull the actual data record out of a raw log line.
 29      Tries, in order: the whole line as-is; the substring between the
 30      first '{' and last '}'; and, if that dict doesn't contain any
 31      recognized field, one level of unwrapping through common logger
 32      wrapper keys (message/data/payload/...). Returns a dict or None.
 33      """
 34      if not isinstance(raw, str):
 35          return None
 36      candidates = [raw]
 37      start, end = raw.find("{"), raw.rfind("}")
 38      if start != -1 and end != -1 and end > start:
 39          candidates.append(raw[start:end + 1])
 40      for candidate in candidates:
 41          obj = _try_parse_dict(candidate)
 42          if obj is None:
 43              continue
 44          if _looks_like_data(obj):
 45              return obj
 46          # Not directly recognizable — maybe the real payload is nested
 47          # inside a logger wrapper field as a JSON/dict string.
 48          for field in _LOGGER_NESTED_FIELDS:
 49              inner = obj.get(field)
 50              if isinstance(inner, str):
 51                  nested = _try_parse_dict(inner)
 52                  if nested is not None and _looks_like_data(nested):
 53                      return nested
 54              elif isinstance(inner, dict) and _looks_like_data(inner):
 55                  return inner
 56      return None  
```

**After**
```python
KV_RE = re.compile(r'"([^"\\]+)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|true|false|null)')

def parse_raw(raw, depth=0):
    s = raw.strip().lstrip("\ufeff").replace("\x00", "") if isinstance(raw, str) else raw
    for _ in range(3):                                   # JSON written as a quoted string
        if not isinstance(s, str):
            break
        obj = None
        try:
            obj = json.loads(s, strict=False)
        except ValueError:
            for m in re.finditer(r"[{\[]", s):           # log prefix / stray trailing characters
                for text in (s[m.start():], re.sub(r",\s*([}\]])", r"\1", s[m.start():])):
                    try:
                        obj = DECODER.raw_decode(text)[0]
                        break
                    except ValueError:
                        continue
                if obj is not None:
                    break
        if obj is None:                                  # truncated or broken: keep every field that is complete
            start = s.find("{")
            tail = s[start:] if start >= 0 else ""
            found = list(KV_RE.finditer(tail))
            if found and found[-1].end() >= len(tail.rstrip()):
                found = found[:-1]                       # the last value may have been cut mid-way ("45" for "4500")
            if not found:
                return None
            obj = {}
            for m in found:
                try:
                    obj.setdefault(m.group(1), json.loads(m.group(2), strict=False))
                except ValueError:
                    pass
        s = obj
    if not isinstance(s, dict):
        return None
    if not any(LOOKUP.get(norm_key(k)) in ("title", "variant", "job", "width") for k in flatten(s)) and depth < 3:
        for k in WRAPPERS:                               # logger wrapper
            if isinstance(s.get(k), (str, dict)):
                inner = parse_raw(s[k], depth + 1)
                if inner:
                    return inner
    return s
```

**How it works**: the line is parsed with `strict=False` (tabs allowed); a log prefix or trailing junk is skipped by decoding from each `{`; trailing commas are removed. If the line cannot be parsed at all, every complete `"key": value` pair is salvaged, and the last pair is dropped when it runs to the very end of the text, because a value cut mid-way (`45` for `4500`) would be wrong.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| json: log prefix + trailing comma | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| json: literal tab inside a string | `4500` | ✘ <no row> | ✔ 4500 | ✔ 4500 |
| json: truncated after bitrate | `4500` | ✘ <no row> | ✔ 4500 | ✘ <no row> |
| json: truncated, duration (cut off) | `None` | ✘ <no row> | ✔ None | ✘ <no row> |

---

## 7. Codec tags

**Your code**: an exact lookup after lowercasing, including the guesses `"1"` for `av1` and `"9"` for `vp9`.

**Gold code**: `gold_submit.py` L341–366 (`_codec_text`, `_codec`): an alias table plus RFC 6381 prefixes; it does not map bare digits.

**Example input**: `"avc1.64001f"`, `"hev1.1.6.L93.B0"`, `"libx265"`, `"x264"`, `"1"`, `"prores"`.

**Your behavior**: the first four return `None`; `"1"` becomes `av1`, a guess; `"prores"` is `None`, which is correct.

**Gold behavior**: `h264`, `h265`, `h265`, `h264`, `None`, `None`.

**Why it matters**: `codec` was missed 161,388 times and wrong 1,023 times `[measured]`; the guessed digits may account for some of the wrong values `[inferred]`. Codec tags from 3 toolchains are 6.0% of the stream (74% recovered).

**Before** (`handler.py` L9, L144–154)
```python
  9  CODEC_ALIASES = {"264": "h264","h264": "h264","avc": "h264","265": "h265","h265": "h265","hevc": "h265","av1": "av1","vp9": "vp9","1":"av1","9":"vp9"}
...
144  def normalize_codec(codec):
145      if codec is None:
146          return None
147      if isinstance(codec, int):
148          value = str(codec)
149      elif isinstance(codec, str):
150          value = codec.strip().lower()
151      else:
152          return None
153      # Returns only h264, h265, av1, vp9, or None
154      return CODEC_ALIASES.get(value)
```

**After**
```python
def clean_codec(v):
    s = re.sub(r"[^a-z0-9.]", "", str(v).lower())
    if s.startswith(("avc1", "avc3")):
        return "h264"
    if s.startswith(("hvc1", "hev1")):
        return "h265"
    if s.startswith("av01"):
        return "av1"
    if s.startswith(("vp09", "vp9")):
        return "vp9"
    s = s.replace(".", "")
    if s in {"h264", "avc", "x264", "libx264"}:
        return "h264"
    if s in {"h265", "hevc", "x265", "libx265"}:
        return "h265"
    if s in {"av1", "libaom", "libaomav1", "libsvtav1", "svtav1"}:
        return "av1"
    if s in {"libvpxvp9", "libvpx"}:
        return "vp9"
    return None
```

**How it works**: RFC 6381 tags are matched by prefix (`avc1`, `hvc1`/`hev1`, `av01`, `vp09`), library and marketing names by a small table, and anything else (including mezzanine codecs and bare digits) is null.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| codec: 'avc1.64001f' | `h264` | ✘ None | ✔ h264 | ✔ h264 |
| codec: 'hev1.1.6.L93.B0' | `h265` | ✘ None | ✔ h265 | ✔ h265 |
| codec: 'libx265' | `h265` | ✘ None | ✔ h265 | ✔ h265 |
| codec: 'x264' | `h264` | ✘ None | ✔ h264 | ✔ h264 |
| codec: '1' | `None` | ✘ av1 | ✔ None | ✔ None |
| codec: 'prores' | `None` | ✔ None | ✔ None | ✔ None |

---

## 8. Emit timing and re-delivery

**Your code**: `process` emits a row the first time it sees a key and again whenever a newer `packaged_at` arrives; `finalize` returns `[]`.

**Gold code**: `gold_submit.py` L565–648: `process` only merges into a held table (newer run wins, same-instant ties fill holes), and `finalize` emits one row per key.

**Example input**: the same key delivered twice, the older run first (10:00, bitrate 4000) and the newer run second (11:00, bitrate 4500); and the reverse order.

**Your behavior**: the older run is emitted on first sight and the newer run is emitted again, so the key has two rows. If the newer run comes first, the older one is correctly ignored.

**Gold behavior**: one row, with the newer values, in both orders.

**Why it matters**: 14 rows were a second row for a key already emitted, costing 28 points `[measured]`. That is small today, but emit-on-first-sight can never take a row back, and it blocks the job-close inheritance in section 2.

**Before** (`handler.py` L260–287)
```python
260  class Handler:
261      def __init__(self):
262          self.records = {}
263      def process(self, raw):
264          try:
265              payload = extract_json_payload(raw)
266              if payload is None:
267                  return []
268              normalized = normalize_keys(payload)
269              if not check_quality(normalized):
270                  return []
271              row = clean(normalized)
272              if row is None:
273                  return []
274  
275              key = (row['title_id'], row['rendition'])
276              existing = self.records.get(key)
277  
278              # Skip if this record is older than what we already have for this key
279              if existing is not None and row['packaged_at'] <= existing['packaged_at']:
280                  return []
281              self.records[key] = row
282              return [row]  
283          except (TypeError, ValueError, KeyError, AttributeError, OverflowError, OSError):
284              return []
285      
286      def finalize(self):
287          return [] 
```

**After**
```python
class Handler:                                           # excerpt: _accept() and finalize()
    def _accept(self, title, rendition, c, ctx=None):
        inst, row = self._row(title, rendition, c, ctx)
        key = (title, rendition)
        cur = self.held.get(key)
        if cur is None:
            self.held[key] = [inst, row]
        elif inst is not None and (cur[0] is None or inst > cur[0]):
            self.held[key] = [inst, row]                 # a newer package run replaces the older one
        elif inst == cur[0]:                             # same run: fill holes only
            for k, v in row.items():
                if cur[1].get(k) is None:
                    cur[1][k] = v

    def finalize(self):
        return [row for _inst, row in self.held.values()]
```

**How it works**: `process` only collects. For each `(title, rendition)` the newest package run wins; a row with no time loses to one with a time; two lines from the same run fill each other's holes. `finalize` writes one row per key.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| re-delivery: older run first, then newer | `4500` | ✔ 4500 | ✔ 4500 | ✔ 4500 |
| re-delivery: newer first, older replay later | `4500` | ✔ 4500 | ✔ 4500 | ✔ 4500 |

Rows emitted for one key delivered twice (old run, then new run) `[estimate]`:

| Handler | Rows emitted |
|---|---:|
| Before | **2** (both from `process`) |
| After | **1** (from `finalize`) |
| Gold | 1 (from `finalize`) |

---

## Recommended pattern

`process()` collects, `finalize()` emits once. The full proposed handler (every After above, assembled) follows. Run it against the sample before submitting.

<details>
<summary>Complete proposed <code>handler.py</code></summary>

```python
import json
import math
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation

NULLS = {"", "null", "none", "nil", "nan", "nat", "n/a", "na", "unknown", "undefined", "-", "--", "not available"}
RUNGS = {240, 360, 480, 720, 1080, 2160}
WIDTH_TO_RUNG = {426: 240, 427: 240, 640: 360, 854: 480, 853: 480, 1280: 720, 1920: 1080, 3840: 2160}
NICKNAMES = {"4k": "2160p", "uhd": "2160p", "fullhd": "1080p", "fhd": "1080p", "hd": "720p"}
ALIASES = {
    "title": {"titleid", "title", "contentid", "assetid"},
    "job": {"jobid", "encodingjobid", "encodejobid", "job"},
    "variant": {"variant", "rendition", "resolution", "quality", "res", "profile", "rung", "label", "preset"},
    "width": {"width", "videowidth", "w"},
    "height": {"height", "videoheight", "h"},
    "codec": {"codec", "videocodec", "vcodec", "encoding", "enc", "codecs", "codecname"},
    "bitrate": {"bitrate", "bitratekbps", "kbps", "bitratebps", "bps", "bandwidth", "bitratembps", "mbps", "avgbitrate"},
    "duration": {"duration", "durationsec", "durations", "durationms", "durationmin", "length", "runtime"},
    "packaged": {"packaged", "packagedat", "timestamp", "createdat", "time", "completedat"},
}
LOOKUP = {a: f for f, names in ALIASES.items() for a in names}
WRAPPERS = ("message", "msg", "log", "data", "payload", "body")
LISTS = ("outputs", "renditions", "variants", "items")
CLOSE_WORDS = {"close", "closed", "complete", "completed", "done", "finished", "end", "jobclose", "jobclosed", "jobcomplete"}
DECODER = json.JSONDecoder(strict=False)


def norm_key(k):
    return re.sub(r"[^a-z0-9]", "", str(k).lower())


def is_null(v):
    return v is None or (isinstance(v, str) and v.strip().lower() in NULLS) or (isinstance(v, float) and not math.isfinite(v))


# ---- 1. read one log line, however it was damaged -----------------------------------------
KV_RE = re.compile(r'"([^"\\]+)"\s*:\s*("(?:[^"\\]|\\.)*"|-?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?|true|false|null)')


def parse_raw(raw, depth=0):
    s = raw.strip().lstrip("\ufeff").replace("\x00", "") if isinstance(raw, str) else raw
    for _ in range(3):                                   # JSON written as a quoted string
        if not isinstance(s, str):
            break
        obj = None
        try:
            obj = json.loads(s, strict=False)
        except ValueError:
            for m in re.finditer(r"[{\[]", s):           # log prefix / stray trailing characters
                for text in (s[m.start():], re.sub(r",\s*([}\]])", r"\1", s[m.start():])):
                    try:
                        obj = DECODER.raw_decode(text)[0]
                        break
                    except ValueError:
                        continue
                if obj is not None:
                    break
        if obj is None:                                  # truncated or broken: keep every field that is complete
            start = s.find("{")
            tail = s[start:] if start >= 0 else ""
            found = list(KV_RE.finditer(tail))
            if found and found[-1].end() >= len(tail.rstrip()):
                found = found[:-1]                       # the last value may have been cut mid-way ("45" for "4500")
            if not found:
                return None
            obj = {}
            for m in found:
                try:
                    obj.setdefault(m.group(1), json.loads(m.group(2), strict=False))
                except ValueError:
                    pass
        s = obj
    if not isinstance(s, dict):
        return None
    if not any(LOOKUP.get(norm_key(k)) in ("title", "variant", "job", "width") for k in flatten(s)) and depth < 3:
        for k in WRAPPERS:                               # logger wrapper
            if isinstance(s.get(k), (str, dict)):
                inner = parse_raw(s[k], depth + 1)
                if inner:
                    return inner
    return s


def flatten(obj, depth=0):
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat


def expand(rec):                                         # one line may carry a list of outputs
    for k in LISTS:
        if isinstance(rec.get(k), list) and rec[k] and all(isinstance(x, dict) for x in rec[k]):
            base = {a: b for a, b in rec.items() if a != k}
            return [{**base, **x} for x in rec[k]]
    return [rec]


def canonical(rec):                                      # field -> (value, original key); null spellings never take a slot
    out = {}
    for k, v in flatten(rec).items():
        f = LOOKUP.get(norm_key(k))
        if f and f not in out and not is_null(v):
            out[f] = (v, k)
    return out


# ---- 2. one cleaner per field --------------------------------------------------------------
def clean_title(v):
    m = re.fullmatch(r"T-?(\d{7})", re.sub(r"\s+", "", str(v)).upper())
    return "T-" + m.group(1) if m else None


def rung_from_text(t):
    s = re.sub(r"\s+", "", str(t).lower())
    if s in NICKNAMES:
        return NICKNAMES[s]
    m = re.fullmatch(r"(\d{3,4})x(\d{3,4})p?", s)        # 1920x1080: the WIDTH names the rung (scope titles are wider)
    if m:
        r = WIDTH_TO_RUNG.get(int(m.group(1)))
        return f"{r}p" if r else None
    m = re.search(r"(?<!\d)(\d{3,4})p", s)               # 720p, video_1080p_h264
    if m and int(m.group(1)) in RUNGS:
        return f"{int(m.group(1))}p"
    m = re.fullmatch(r"(\d{3,4})(w|wide|width)?", s)
    if m:
        n = int(m.group(1))
        if not m.group(2) and n in RUNGS:
            return f"{n}p"
        r = WIDTH_TO_RUNG.get(n)
        return f"{r}p" if r else None
    return None


def clean_rendition(c):
    v = c.get("variant", (None, None))[0]
    if isinstance(v, dict):                              # {"width": 1920, "height": 1080}
        w = next((x for k, x in v.items() if norm_key(k) in ALIASES["width"] and not is_null(x)), None)
        v = f"{w}w" if w is not None else None
    r = rung_from_text(v) if v is not None else None
    if r is None and "width" in c:
        r = rung_from_text(f"{c['width'][0]}w")
    if r is None and "height" in c and "variant" not in c:
        r = rung_from_text(c["height"][0])
    return r


def clean_codec(v):
    s = re.sub(r"[^a-z0-9.]", "", str(v).lower())
    if s.startswith(("avc1", "avc3")):
        return "h264"
    if s.startswith(("hvc1", "hev1")):
        return "h265"
    if s.startswith("av01"):
        return "av1"
    if s.startswith(("vp09", "vp9")):
        return "vp9"
    s = s.replace(".", "")
    if s in {"h264", "avc", "x264", "libx264"}:
        return "h264"
    if s in {"h265", "hevc", "x265", "libx265"}:
        return "h265"
    if s in {"av1", "libaom", "libaomav1", "libsvtav1", "svtav1"}:
        return "av1"
    if s in {"libvpxvp9", "libvpx"}:
        return "vp9"
    return None                                          # outside the contract (prores ...) or an unknown tag


def _number(text):
    s = text.strip()
    if "," in s and "." in s:
        s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", "") if re.fullmatch(r"\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
    return Decimal(s)


KBPS = {"bps": Decimal("0.001"), "b/s": Decimal("0.001"), "kbps": Decimal(1), "kb/s": Decimal(1), "k": Decimal(1),
        "mbps": Decimal(1000), "mb/s": Decimal(1000), "m": Decimal(1000), "gbps": Decimal(10**6)}


def clean_bitrate(v, key):                               # whole kbps, or None
    try:
        if isinstance(v, bool):
            return None
        unit = None
        if isinstance(v, str):
            m = re.fullmatch(r"\s*([\d.,]+)\s*([A-Za-z/]*)\s*", v)
            if not m:
                return None
            d, unit = _number(m.group(1)), m.group(2).lower() or None
        else:
            d = Decimal(str(v))
        nk = norm_key(key)
        unit = unit or ("mbps" if nk.endswith("mbps") else "kbps" if nk.endswith("kbps") else
                        "bps" if nk.endswith("bps") or nk == "bandwidth" else "kbps")
        if unit not in KBPS:
            return None
        kbps = d * KBPS[unit]
        if not kbps.is_finite() or kbps <= 0 or kbps != kbps.to_integral_value():
            return None
        return int(kbps)
    except (InvalidOperation, ValueError):
        return None


DUR_UNITS = {"ms": 0.001, "s": 1, "sec": 1, "secs": 1, "second": 1, "seconds": 1, "m": 60, "min": 60, "mins": 60,
             "minute": 60, "minutes": 60, "h": 3600, "hr": 3600, "hrs": 3600, "hour": 3600, "hours": 3600}


def clean_duration(v, key):                              # seconds with 3 decimals, or None
    try:
        if isinstance(v, bool):
            return None
        secs = None
        if isinstance(v, str):
            s = v.strip()
            m = re.fullmatch(r"(?:(\d+):)?(\d{1,2}):(\d{2}(?:\.\d+)?)", s)          # 01:30:00  or  90:00
            iso = re.fullmatch(r"PT(?:(\d+(?:\.\d+)?)H)?(?:(\d+(?:\.\d+)?)M)?(?:(\d+(?:\.\d+)?)S)?", s, re.I)
            u = re.fullmatch(r"(\d+(?:\.\d+)?)\s*([A-Za-z]+)", s)
            if m:
                secs = int(m.group(1) or 0) * 3600 + int(m.group(2)) * 60 + float(m.group(3))
            elif iso and any(iso.groups()):
                secs = sum(float(x or 0) * f for x, f in zip(iso.groups(), (3600, 60, 1)))
            elif u and u.group(2).lower() in DUR_UNITS:
                secs = float(u.group(1)) * DUR_UNITS[u.group(2).lower()]
            else:
                v = float(_number(s))
        if secs is None:
            nk = norm_key(key)
            secs = float(v) * (0.001 if nk.endswith("ms") else 60 if nk.endswith("min") else 1)
        return round(secs, 3) if math.isfinite(secs) and secs > 0 else None      # 0, -1, NaN are "no value"
    except (ValueError, InvalidOperation, OverflowError):
        return None


TIME_RE = re.compile(r"(\d{4})[-/](\d{2})[-/](\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?)?\s*(Z|UTC|GMT|[+-]\d{2}:?\d{2})?", re.I)


def clean_time(v):                                       # aware UTC datetime, or None
    try:
        if isinstance(v, bool):
            return None
        if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
            v = float(v)
        if isinstance(v, (int, float)):
            n = float(v)
            n = n / 1e9 if n >= 1e17 else n / 1e6 if n >= 1e14 else n / 1e3 if n >= 1e11 else n
            return datetime.fromtimestamp(n, tz=timezone.utc)
        m = TIME_RE.fullmatch(str(v).strip())
        if not m:
            return None
        y, mo, d, hh, mm, ss, tz = m.groups()
        dt = datetime(int(y), int(mo), int(d), int(hh or 0), int(mm or 0), int(ss or 0), tzinfo=timezone.utc)
        if tz and tz.upper() not in ("Z", "UTC", "GMT"):
            sign = 1 if tz[0] == "+" else -1
            digits = tz[1:].replace(":", "")
            dt = dt - sign * timedelta(hours=int(digits[:2]), minutes=int(digits[2:]))
        return dt
    except (ValueError, OverflowError, OSError):
        return None


def is_close(rec):
    for k in ("event", "eventtype", "type", "kind", "status", "state", "action"):
        v = rec.get(k)
        if isinstance(v, str) and norm_key(v) in CLOSE_WORDS:
            return True
    return False


def job_id(c):
    v = c.get("job", (None,))[0]
    return str(v).strip() or None if isinstance(v, (str, int)) and not isinstance(v, bool) else None


# ---- 3. hold per (title, rendition); the newest package run wins; emit once in finalize --------
class Handler:
    def __init__(self):
        self.held = {}                                   # (title, rendition) -> [instant, row dict]
        self.jobs = {}                                   # job id -> {"title", "duration", "pending": [...]}

    def _row(self, title, rendition, c, ctx):
        dur = c.get("duration") or (ctx or {}).get("duration")
        t = clean_time(c["packaged"][0]) if "packaged" in c else None
        row = {
            "title_id": title,
            "rendition": rendition,
            "codec": clean_codec(c["codec"][0]) if "codec" in c else None,
            "bitrate_kbps": clean_bitrate(*c["bitrate"]) if "bitrate" in c else None,
            "duration_s": clean_duration(*dur) if dur else None,
            "packaged_at": t.strftime("%Y-%m-%dT%H:%M:%SZ") if t else None,
        }
        return t, row

    def _accept(self, title, rendition, c, ctx=None):
        inst, row = self._row(title, rendition, c, ctx)
        key = (title, rendition)
        cur = self.held.get(key)
        if cur is None:
            self.held[key] = [inst, row]
        elif inst is not None and (cur[0] is None or inst > cur[0]):
            self.held[key] = [inst, row]                 # a newer package run replaces the older one
        elif inst == cur[0]:                             # same run: fill holes only
            for k, v in row.items():
                if cur[1].get(k) is None:
                    cur[1][k] = v

    def process(self, raw):
        try:
            rec = parse_raw(raw)
            for r in (expand(rec) if rec else []):
                c = canonical(r)
                job = job_id(c)
                title = clean_title(c["title"][0]) if "title" in c else None
                rendition = clean_rendition(c)
                if job is None:
                    if title and rendition:
                        self._accept(title, rendition, c)
                    continue
                ctx = self.jobs.setdefault(job, {"title": None, "duration": None, "pending": []})
                if is_close(r) or rendition is None:     # a close line names the job's title but no rendition
                    ctx["title"] = title or ctx["title"]
                    ctx["duration"] = c.get("duration") or ctx["duration"]
                    if ctx["title"]:
                        for pc, pr in ctx["pending"]:
                            self._accept(ctx["title"], pr, pc, ctx)
                        ctx["pending"] = []
                    continue
                title = title or ctx["title"]
                if title:
                    self._accept(title, rendition, c, ctx)
                else:
                    ctx["pending"].append((c, rendition))   # output logged before its close line
        except Exception:
            pass
        return []                                        # never emit here

    def finalize(self):
        return [row for _inst, row in self.held.values()]
```

</details>

## Checklist

1. **Read the rung from the width**, and never depend on key order.
2. **Never let a missing time or title drop a row early.** Hold it and resolve it later (job close lines, newest run).
3. **Treat 0, -1 and NaN as "no value"**, never as a measurement.
4. **Convert units explicitly** (bps, kbps, Mbps; ms, timecode, ISO) instead of taking the first digits.
5. **Emit from one place only**, so a newer run can replace an older one without a second row.
