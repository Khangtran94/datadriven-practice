# Week 10 – The Ceiling: handler.py vs gold_submit.py

**Your score:** 0.8185 (#4 of 6, top 67%)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`  
**Records recovered:** 801,178 of 855,838  
**Penalties:** 60,340 second rows for a key already emitted + 9,855 rows that matched no record

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Emission timing / duplicates | 60,340 extra rows for keys already emitted. `process` returns rows immediately; corrections emit a second row. Gold holds everything and emits only once in `finalize`. |
| 2 | Split / continued lines | 70% recovery on "Split over 2 log lines". No pending-body buffer; second line is treated as a new (usually invalid) report. |
| 3 | Time without Z / 2400 | 0% recovery on "A time with no Z" and "Midnight as hour 2400". Time regex requires the Z; hour 24 is rejected. |
| 4 | Hand-typed units & two-part values | 68% on KTS/KM/QNH and two-part groups. Wind/visibility/altimeter regexes miss KTS, QNH, A 3001, 180/12KT, 10 SM, etc. |
| 5 | Bulletin headings & archive wrappers | 32% on bulletin headings. Station/time extraction does not strip SAUS70 KWBC … style headers or date-line wrappers. |
| 6 | Wind in m/s & other units | Partial. MPS is handled, but many real-world unit variants and O-for-0 slips are missed. |
| 7 | Robust METAR tokenization | Gold uses a large set of pre-compiled patterns that tolerate spacing, missing zeros, CB/TCU, NDV, TEMPO/BECMG cut-offs, etc. |

---

## 1. Emission timing / duplicates (60k second-row penalty)

### Your current code (before)

```python
class Handler:
    def __init__(self):
        self.records_map = {}

    def process(self, raw):
        …
        extracted = extract_columns(rows)
        out = []
        for row in extracted:
            key = _record_key(row)
            values = _pack_record(row)
            if self.records_map.get(key) == values:
                continue
            self.records_map[key] = values
            out.append(row)          # ← emits every time the values change
        return out

    def finalize(self):
        return []                    # ← never emits the final unique set
```

### Proposed change (after)

```python
class Handler:
    def __init__(self):
        self.held = {}               # key → packed values (last write wins)

    def process(self, raw):
        …
        for row in extracted:
            key = _record_key(row)
            if key is None:
                continue
            self.held[key] = _pack_record(row)   # overwrite, never emit yet
        return []                                 # always empty

    def finalize(self):
        return [_unpack_record(k, v) for k, v in self.held.items()]
```

### Explanation

The scorer collects every list returned by `process` **plus** the list returned by `finalize`.  
When a later line carries a correction (or a more complete parse) for the same `(station, observed_at)`, your code emits a second row. Those 60,340 extras are scored as wrong.  
Gold never returns anything from `process`; it only returns the final unique map from `finalize`. Last write wins, and each key appears exactly once.

**Example input**  
```
{"report": "METAR EGLL 311851Z 18012KT …", "received_at": "…"}
{"report": "METAR EGLL 311851Z 18015KT …", "received_at": "…"}   # correction
```

**Your behavior**  
Emits two rows for EGLL|2026-01-31T18:51:00Z. The second is counted as a duplicate key.

**Gold behavior**  
Stores the second values, returns only one row in `finalize`.

**Why it matters**  
This single architectural mismatch accounts for the bulk of the 140 k point loss mentioned in the README.

**What to change**  
- Make `process` always return `[]`.  
- Keep only the latest packed values per key.  
- Emit the entire unique table from `finalize`.

---

## 2. Split / continued lines

### Your current code (before)

No state between calls. Each `raw` is parsed in isolation. A continuation line that starts with spaces and has no station/time is either dropped or produces a bad row.

### Proposed change (after)

(Keep a `self.pending` buffer exactly as gold does.)

```python
def process(self, raw):
    record = parse_record(raw)
    if record is None:
        self._finish_pending()
        return []
    report, received, feed = record
    header = parse_header(report, received)
    if header is None:                       # possible continuation
        if self.pending:
            … join body + tail if same circuit …
        return []
    self._finish_pending()
    … store or set pending …
    return []
```

### Explanation

Collectors that wrap at 69 characters or split on line breaks produce two log lines for one METAR. The second line has no station or time of its own. Gold keeps the open body and stitches the tail when the next line arrives on the same circuit. Your code never stitches, so ~30 % of those reports are lost or corrupted.

**Example input**  
Line 1: `METAR EGLL 311851Z 18012KT 9999 BKN`  
Line 2: `  020 15/10 Q1013=`

**Your behavior**  
First line may emit a partial row; second line is ignored or produces a mismatch.

**Gold behavior**  
Joins the body, stores the complete observation, emits once at the end.

---

## 3. Time without Z and hour 2400

### Your current code (before)

```python
OBSERVATION_TIME_RE = re.compile(r"^\d{6}Z$")
…
timestamp_match = re.search(r"\b(\d{2})(\d{2})(\d{2})Z\b", body)
if hour > 23 or minute > 59:
    return None
```

### Proposed change (after)

Accept optional Z, treat 2400 as 0000 of the next day, and prefer the candidate closest to the received timestamp (including month/year rollover).

```python
# gold-style head pattern already does this
# hour == 24 → next day 00:00
```

### Explanation

Many stations omit the Z or write 312400Z for midnight. Your strict regex and `hour > 23` check drop those reports entirely (0 % recovery). Gold’s header regex and date arithmetic recover them and correctly cross month/year boundaries when the log stamp is near midnight.

---

## 4. Hand-typed units and two-part values

### Your current code (before)

Wind regex expects `KT|MPS|KMH` and a tight digit pattern. Visibility looks for `####` or `N SM` forms. Altimeter looks only for `A####` / `Q####`.

### Proposed change (after)

Use the broader patterns from gold:

```python
_WIND = re.compile(r"(?:[0-9]{3}|VRB|///)/?P?([0-9]{1,3})(?:GP?(?:[0-9]{1,3}|//))?(KT|KTS|MPS|KMH|KPH)")
_ALTIMETER_TYPED = re.compile(r"(A|Q|QNH)([0-9]{2,4}(?:[.,][0-9]{1,3})?)")
# plus a token join step for "180 / 12KT", "10 SM", "A 3001", etc.
```

### Explanation

Observers type from paper forms: `18012KTS`, `CALM`, `10KM`, `QNH1013`, `A 3001`, `180/12KT`, `22 / 14`. Your regexes miss a large fraction of these. Gold’s patterns plus a small amount of token re-joining recover them.

---

## Recommended pattern (copy-paste skeleton)

```python
class Handler:
    def __init__(self):
        self.held = {}          # (station, observed_at) → packed tuple
        self.pending = None     # for split lines

    def process(self, raw):
        # parse, stitch continuations, update self.held[key] = values
        # never return rows
        return []

    def finalize(self):
        # flush pending, return list of unique rows
        return [unpack(k, v) for k, v in self.held.items()]
```

Keep only the current (last) values for each key. Prefer compact tuples. Return `[]` from every `process` call. Emit the final table only from `finalize`.

---

The remaining gaps (bulletin headers, O-for-0, TEMPO/BECMG cut-off, CAVOK, CB/TCU, etc.) are real but secondary once the emission contract and the most common parsing holes are fixed. The gold file is a compact, battle-tested METAR tokenizer; studying its regex set and the pending-line logic is the fastest way to close the rest of the gap.
