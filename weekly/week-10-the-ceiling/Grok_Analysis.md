# Week 10 – The Ceiling: handler.py vs gold_submit.py

**Your score:** 0.8185 (#4 of 6, top 67%)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

60 340 rows were a second row for a key already emitted and 9 855 rows matched no record. Together they cost 140 390 points. Column correctness is solid on station/observed_at (~94 %) but drops on altimeter_hpa / visibility_m / wind_kt / temp_c (78–84 %).

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Emit-in-process + empty finalize | Emits a row as soon as it is seen; later revision for the same (station, observed_at) becomes a second row → 60 340 “already emitted” penalties. finalize() returns []. |
| 2 | No split-line / pending recovery | Reports that wrap across two log lines are incomplete or dropped. Gold keeps a pending body and joins the continuation. |
| 3 | Time forms without Z / hour 2400 | “A time with no Z” (2.9 % of stream) recovered 0 %. Midnight logged as 2400 is rejected. Gold accepts both. |
| 4 | Typed units and split groups (KTS, KM, QNH, 2-part values) | 17 % of stream is a value typed in two parts; 16 % is hand-typed units. Your regexes expect glued forms. |
| 5 | Altimeter / visibility / wind / temp extractors | Highest wrong+missed counts. Gold has broader patterns (legacy fields, QNH, mixed SM, MPS, tenths remarks, O→0). |
| 6 | Bulletin / archive / lower-case / O-for-zero | Secondary but frequent enough to move the remaining gap. |

---

## 1. Emit-in-process + empty finalize (largest single cost)

### Your current code (before)

```python
class Handler:
    def __init__(self):
        self.output_rows = None
        self.records_map = {}

    def process(self, raw):
        # ... normalize + extract ...
        out = []
        for row in extracted:
            key = _record_key(row)
            values = _pack_record(row)
            if self.records_map.get(key) == values:
                continue
            self.records_map[key] = values
            out.append(row)          # emit immediately
        return out

    def finalize(self):
        return []                    # never emit here
```

### Proposed change (after)

```python
class Handler:
    def __init__(self):
        self.held = {}               # (station, observed_at) → weather tuple
        self.pending = None          # optional split-line state

    def process(self, raw):
        # parse + extract; update self.held[key] = weather
        # never return rows here
        return []

    def finalize(self):
        # finish any pending, then emit every held key once
        rows = []
        for (station, observed_at), weather in self.held.items():
            wind, vis, ceil, temp, pressure = weather
            rows.append({
                "station": station,
                "observed_at": observed_at,
                "wind_kt": wind,
                "visibility_m": vis,
                "ceiling_ft": ceil,
                "temp_c": temp,
                "altimeter_hpa": pressure,
            })
        self.held.clear()
        return rows
```

### Explanation

- **Before**: a later correction or re-send for the same station+time produces a second emitted row. The scorer counts it as “second row for a key already emitted”.
- **After**: only one row per key is ever emitted, and it is the last (or best) version that was stored. This is exactly what gold does.

**Example input**  
Same EGLL 311200Z appears twice; second copy has a corrected visibility.

**Your behavior**  
Two rows emitted for the same key → penalty.

**Gold behavior**  
Only the final stored version is emitted in finalize.

**Why it matters**  
60 340 rows × penalty is the single largest score loss.

**What to change**  
Never emit from process. Keep one winner per (station, observed_at). Emit only from finalize.

---

## 2. Split reports across two log lines

### Your current code (before)

No pending state. Each process call is treated as a complete report. A continuation line that starts with spaces / lacks station+time is dropped or produces a partial row.

### Proposed change (after) — pattern from gold

```python
def process(self, raw):
    record = _record(raw)
    if record is None:
        self._finish_pending()
        return []
    report, received, feed = record
    report = _prepare(report)
    header = _header(report, received)
    if header is None:
        if self.pending is not None:
            # try to join continuation
            joined = _continued_body(body, tail)
            if joined is not None and _same_circuit(...):
                self._store(...)
                self.pending = None
            else:
                self._finish_pending()
        return []
    self._finish_pending()
    # ... store or set pending if no terminator
    return []
```

### Explanation

6 % of the stream is split over two lines. Gold keeps the incomplete body in `self.pending` and joins the next line when it is clearly a continuation of the same circuit.

**Why it matters**  
Incomplete bodies produce missing or wrong wind / visibility / ceiling / temp / altimeter.

**What to change**  
Add a small pending state and a continuation recognizer (gold’s `_CONTINUATION` / `_continued_body`).

---

## 3. Observation time without Z and hour 2400

### Your current code (before)

```python
OBSERVATION_TIME_RE = re.compile(r"^\d{6}Z$")
# extract_observed_at looks for \b(\d{2})(\d{2})(\d{2})Z\b
# hour > 23 is rejected
```

### Proposed change (after)

```python
# Accept 6 digits with optional Z / UTC
# Accept hour 24 as 00 of the next calendar day
# Use received_at (or archive day) as anchor to resolve day-of-month
```

Gold’s `_HEAD` and `_observation_day` already do this; midnight 2400 becomes 00:00 of the following day, and a missing Z is still matched.

**Example input**  
`311851` (no Z) or `312400Z`.

**Your behavior**  
No observed_at → row dropped (0 % recovery for “time with no Z”).

**Gold behavior**  
Observed_at is recovered; row is kept.

**Why it matters**  
2.9 % of the stream has no Z; another 0.2 % uses 2400. Both are free points once the pattern is widened.

---

## 4. Typed units and values split into two tokens

Conditions that cost the most:

- “A value typed in 2 parts” (17.2 %)
- “KTS, KM, QNH: units by hand” (15.9 %)
- “Minus signs and loose digits”
- “Miles with a fraction” (already partially handled)
- “Wind in m/s”

### Your current code (before)

```python
WIND_RE = re.compile(
    r"(?:^|\s)(?:[0-9]{3}|VRB)([0-9]{2,3})"
    r"(?:G[0-9]{2,3})?(KT|MPS|KMH)(?:\s|=|$)"
)
# visibility looks for glued SM / 4-digit metres
# altimeter looks for Axxxx / Qxxxx only
```

### Proposed change (after)

Gold’s patterns are deliberately loose:

- `_WIND` accepts `KTS`, optional slash, `P` (plus), and missing digits.
- `_MILES` + previous-token logic rebuilds `1 1/2SM`.
- `_ALTIMETER_TYPED` accepts `QNH1013`, `A30.01`, etc.
- `_legacy_field` handles `WIND=18012KTS`, `VIS=10KM`, `QNH=1013`.
- Tokenisation + previous-token memory recovers the two-part forms.

**Why it matters**  
These conditions dominate the remaining wrong/missed cells on wind, visibility and altimeter.

**What to change**  
Widen the regexes (or switch to token-walk + previous token) and add the legacy-field path.

---

## 5. Column extractors (altimeter, visibility, wind, temp, ceiling)

Highest wrong+missed:

| Column | Correct | Wrong | Missed |
|--------|---------|-------|--------|
| altimeter_hpa | 78 % | 2 418 | 187 860 |
| visibility_m | 78 % | 38 436 | 148 675 |
| wind_kt | 80 % | 5 233 | 163 334 |
| temp_c | 84 % | 23 168 | 112 116 |
| ceiling_ft | 91 % | 6 846 | 73 676 |

Gold improvements that matter most:

- Altimeter: accept typed QNH / A with decimal; convert hundredths-of-inch correctly; range-check.
- Visibility: CAVOK → 9999; mixed/fraction SM with previous whole number; NDV ignored; stop at TEMPO/BECMG/RMK.
- Wind: MPS / KMH conversion with integer rounding; KTS accepted.
- Temp: RMK T-group tenths preferred; M-prefix and free-form decimals; one decimal place always.
- Ceiling: BKN/OVC/VV with optional CB/TCU; lowest layer wins; stop at trend groups.

Also useful: letter-O → digit-0 substitution on digit-only groups (A3O01, BKNO15, 1OSM).

---

## 6. Other frequent conditions (secondary)

- Bulletin heading in front (`SAUS70 KWBC 311900`) — strip with `_BULLETIN`.
- Archive date line / tag kept — strip with `_ARCHIVE`.
- Lower-case line — already upper-cased in both solutions.
- Sensors out / NIL / slashes — gold returns None for the missing field and keeps the row.
- TEMPO / BECMG outlooks — both solutions already stop before trend groups; confirm your extractors do the same.
- Sent late after outage — day-of-month resolved against received_at (or New-Year anchor).

---

## Recommended pattern (complete skeleton)

```python
class Handler:
    def __init__(self):
        self.held = {}          # (station, observed_at) → (wind, vis, ceil, temp, pressure)
        self.pending = None     # (station, observed_at, body, received, feed) or None

    def process(self, raw: str) -> list[dict]:
        # 1. JSON → report / received_at / feed
        # 2. prepare (upper, transport chars, strip =)
        # 3. header = station + observed_at + body (handle bulletin/archive/no-Z/2400)
        # 4. if no header: try join to pending; else finish pending
        # 5. if terminator present: store; else set pending
        return []               # never emit here

    def finalize(self) -> list[dict]:
        self._finish_pending()
        rows = []
        for (station, observed_at), weather in self.held.items():
            wind, vis, ceil, temp, pressure = weather
            rows.append({
                "station": station,
                "observed_at": observed_at,
                "wind_kt": wind,
                "visibility_m": vis,
                "ceiling_ft": ceil,
                "temp_c": temp,
                "altimeter_hpa": pressure,
            })
        self.held.clear()
        return rows
```

Keep only the current winner, recover split lines, widen time and unit parsers, and the same extraction logic that already reaches 0.82 will climb further by eliminating the “second row” and “no record” penalties.
