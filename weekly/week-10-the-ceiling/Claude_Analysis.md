# Week 10: The Ceiling: handler.py vs gold_submit.py

Score 0.8185, rank #4/6, +20 points, recovered 801,178/855,838, work per record 1.4x, 468 statements `[measured]`.

Tag legend: `[measured]` from the README, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data, `[not available]` code not in the repo, `[untested]` not run.

## Why the score is not higher

60,340 rows were a second row for a key already emitted and 9,855 rows matched no record, which cost 140,390 points together `[measured]`. Split up: 60,340 × 2 = 120,680 and 9,855 × 2 = 19,710. The ratio of 2 points per row is the same as Week 1 (854,938 rows → 1,709,876 points). So **86% of the lost points come from 1 bug: `process()` emits again when a value changes**. The rest comes from a bulletin heading that gives the wrong station.

## Impact ranking

| # | Area | Cost | Gold |
|---|---|---|---|
| 1 | Emit each time a value changes | 60,340 rows = 120,680 points `[measured]` | `process()` returns `[]`, emits only in `finalize()` |
| 2 | Bulletin heading → wrong station | 9,855 rows = 19,710 points `[measured]`, cause `[inferred]` | Cuts the heading before reading the station |
| 3 | Hand-typed values, odd units | `visibility_m` wrong 38,436; `altimeter_hpa` missed 187,860 `[measured]` | Normalizes tokens, accepts many unit forms |
| 4 | A time with no Z | 2.9% of stream, recovered 0% `[measured]` | `_HEAD` accepts a time without Z |
| 5 | Report split over 2 log lines | 6.0%, recovered 70% `[measured]` | `pending` joins the next line |
| 6 | Minus signs and loose digits | 6.5%, recovered 72% `[measured]` | `_number_ratio` accepts `-`, `M`, 1 digit |

## 1. Emit each time a value changes

**Your lines:** 660-672 and 697-698. **Gold lines:** `process` ends at 427 with `return []`, `finalize` is at 429-446.

**Example:** the same `(EGLL, 2025-12-31T18:50Z)` arrives twice. The old copy has wind 12, the copy "sent again with a fix" has wind 5.

- **You:** copy 1 emits wind 12. Copy 2 has a different value, so it emits another row. The same key has 2 rows, and the second row is penalized 2 points.
- **Gold:** keeps the last copy in `held` and emits 1 row in `finalize()`.

**Before** (`handler.py` 660-672, 697-698):

```python
        out = []
        for row in extracted:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            values = _pack_record(row)
            if self.records_map.get(key) == values:
                continue
            self.records_map[key] = values
            out.append(row)
        return out
...
    def finalize(self):
        return []
```

**After:**

```python
        for row in extracted:
            if not isinstance(row, dict):
                continue
            key = _record_key(row)
            if key is None:
                continue
            self.records_map[key] = _pack_record(row)   # the copy logged last wins
        return []
...
    def finalize(self):
        return self.extract_columns()   # 1 row for each key
```

**How it works:** the README says "the copy logged last still stands", so there is no need to emit early. You overwrite `records_map`, and only at the end return each key exactly once. It is like writing the minutes after the meeting ends, instead of rewriting them every time someone changes their mind. `extract_columns()` and `_unpack_record` already exist in your file, so nothing new has to be written.

**Proof** `[estimate]`: synthetic data with 17,401 keys (3 seeds). The original emits 1,039 duplicate rows, the fixed version emits 0.

## 2. A bulletin heading gives the wrong station

**Your lines:** 244-248. **Gold:** `_BULLETIN` at 19-23 and `_header` at 109-139.

**Example:** `SAUS70 KWBC 311900 KJFK 311853Z 18012KT ...` (no `METAR` word).

- **You:** take `KWBC` as the station. The observation time is still right, so the row gets a key that does not exist in the answer. This is the "matched no record" kind `[inferred]`.
- **Gold:** cuts the heading and gets `KJFK`. I ran both handlers on this line and confirmed the result `[estimate]`.

**Before** (244-248):

```python
    for token in tokens:
        if OBSERVATION_TIME_RE.fullmatch(token):
            break
        if token != "AUTO" and ICAO_RE.fullmatch(token):
            return token
```

**After:** add to the top of `tidy()` (a new function, see section 3), which runs once before every extractor.

```python
BULLETIN_RE = r"^(?:ZCZC[^\n]*\n\s*)?(?:\d{3}\s+)?[A-Z]{4}\d{2}\s+[A-Z]{4}\s+\d{6}(?:\s+(?:CC|RR|AA)[A-Z])?\s+"
t = re.sub(BULLETIN_RE, "", str(report).strip().upper())
```

**How it works:** a heading always has the shape 6 characters (data type + number) + 4 letters (the compiling center) + 6 digits (the time). Recognize exactly that pattern, drop it, and keep only the airport's own report.

**Proof** `[estimate]`: unmatched 482 → 0, recovered 92.1% → 94.9% with only this fix applied.

## 3. Hand-typed values and odd units

**Your lines:** `WIND_RE` 30-33, visibility 393, altimeter 493 and 504. **Gold:** `_WIND` 25 (accepts `KTS`, `KPH`), `_METRES` 27, `_ALTIMETER_TYPED` 33, `_pressure` 189-206.

**Example:** `180/12KT`, `30007 KT`, `10 SM`, `BKN 015`, `22 / 14`, `A 3001`, `18012KTS`, `10KM`, `QNH1013`, `1013HPA`, `A30.01`, `A3O01`, `9999NDV R27L/0800`.

- **You:** `WIND_RE` needs exactly `KT|MPS|KMH` stuck to the digits. `\bA(\d{4})\b` does not accept `A30.01`. Line 393 treats any 4-5 digit token as visibility, so a `3001` after the temperature is read as 3001 m.
- **Gold:** accepts all of these forms.

**Before** (30-33, 393, 493, 504):

```python
WIND_RE = re.compile(
    r"(?:^|\s)(?:[0-9]{3}|VRB)([0-9]{2,3})"
    r"(?:G[0-9]{2,3})?(KT|MPS|KMH)(?:\s|=|$)"
)
...
            if re.fullmatch(r"\d{4,5}", token) and not token.startswith("R"):
...
        a_match = re.search(r"\bA(\d{4})\b", body)
...
        q_match = re.search(r"\bQ(\d{4})\b", body)
```

**After:** a `tidy(report)` function rewrites every hand-typed form into the standard form once, and the old extractors stay as they are:

```python
def tidy(report):
    t = re.sub(BULLETIN_RE, "", str(report).strip().upper())
    t = re.sub(r"\s+", " ", t).strip()
    t = re.sub(r"\b(\d{3}|VRB)/(\d{2,3})(G\d{2,3})? ?(KTS?|MPS|KMH)\b", r"\1\2\3\4", t)  # 180/12KT
    t = re.sub(r"\b((?:\d{3}|VRB)\d{2,3}(?:G\d{2,3})?) (KTS?|MPS|KMH)\b", r"\1\2", t)     # 30007 KT
    t = re.sub(r"\b((?:\d{3}|VRB)\d{2,3}(?:G\d{2,3})?)KTS\b", r"\1KT", t)                 # KTS -> KT
    t = re.sub(r"\b(\d+) SM\b", r"\1SM", t)                                                # 10 SM
    t = re.sub(r"\b(BKN|OVC|FEW|SCT|VV) (\d{3})", r"\1\2", t)                              # BKN 015
    t = re.sub(r"\bA (\d{4})\b", r"A\1", t)                                                # A 3001
    t = re.sub(r"\bQNH ?(\d{4})\b", r"Q\1", t)                                             # QNH1013
    t = re.sub(r"\b(\d{4}) ?HPA\b", r"Q\1", t)                                             # 1013HPA
    t = re.sub(r"\bA(\d{2})[.,](\d{2})\b", r"A\1\2", t)                                    # A30.01
    t = re.sub(r"\b(\d{4})NDV\b", r"\1", t)                                                # 9999NDV
    t = re.sub(r"\bR\d{2}[LCR]?/\S+ ?", "", t)                                             # R27L/0800
    return t
```

Call it at the start of `extract_columns`: `row = dict(row, report=tidy(row.get("report")))`. The full version also converts `KM` to metres, fixes an O typed for a zero (`A3O01`, `BKNO15`), and reads 4 bare digits after the temperature as `A` or `Q` by range (2800-3200 is inches, 850-1100 is hPa).

**How it works:** instead of teaching each extractor every way of typing, you "clean the spelling" once at the door. After that every old regex sees the standard form. To support a new typing style you add 1 line to `tidy()`.

**Proof** `[estimate]` (each fix alone, on top of the original): fixing the wind/cloud/SM forms raises wind 78.4% → 90.1%. Fixing the units raises altimeter 74.0% → 84.0% and visibility 71.2% → 76.5%.

## 4. A time with no Z

**Your lines:** 36 and 524. **Gold:** `_HEAD` 11, where `Z?` is optional.

**Example:** `METAR EGLL 311851 ...` or `311851UTC`.

- **You:** both `OBSERVATION_TIME_RE` (line 36) and the regex on line 524 require a Z, so the time is not found and the whole line is dropped. The README measures 0% `[measured]`.
- **Gold:** accepts a time with no Z.

**Before:**

```python
OBSERVATION_TIME_RE = re.compile(r"^\d{6}Z$")
...
    timestamp_match = re.search(r"\b(\d{2})(\d{2})(\d{2})Z\b", body)
```

**After:** add to `tidy()`, which puts the Z on the time right after the station:

```python
t = re.sub(r"\b((?:METAR|SPECI)(?: COR)? [A-Z]{4} \d{6})(?:UTC)?\b",
           lambda m: m.group(1) + "Z", t)
```

**How it works:** every report is in UTC (the README says so), so the Z is only a signature. Once it is added, the 2 old regexes run as before.

**Proof** `[estimate]`: recovered 92.1% → 97.0%. The number of duplicate rows rises (1,039 → 1,093) because more keys are found, and the fix in section 1 handles exactly that. Only the form with `METAR`/`SPECI` in front was tested. The form without that word is `[untested]`.

## 5. A report split over 2 log lines

**Your lines:** 653-658, each log line is handled on its own. **Gold:** `pending` at 378-379, `_continued_body` 356-373, used in `process` 404-417.

**Example:** line 1 `METAR LIRF 290151Z 21003KT 1500 OVC067`, line 2 `      -10/-12 Q1013=` (starts with spaces, has no station).

- **You:** line 1 has only wind/visibility/ceiling, with temperature and altimeter missing. Line 2 has no station and is dropped.
- **Gold:** holds line 1 in `pending`, joins line 2 to it, and only then parses.

**After** (shortened):

```python
    def _flush(self):
        if self.pending is None:
            return
        held, self.pending = self.pending, None
        rows = [r for r in (normalize_row(held),) if r is not None]
        for row in extract_columns(rows):
            key = _record_key(row)
            if key is not None:
                self.records_map[key] = _pack_record(row)

    def process(self, raw):
        try:
            rows = rows_from_value(parse_raw(raw) or [])
        except (TypeError, ValueError, json.JSONDecodeError, UnicodeDecodeError):
            self._flush(); return []
        for row in rows:
            canon = to_canonical(row)
            report = canon["report"]
            if not isinstance(report, str):
                continue
            if report[:1].isspace() and self.pending is not None:   # second half of a report
                self.pending["report"] += " " + report.strip()
                continue
            self._flush()
            self.pending = dict(canon)
        return []

    def finalize(self):
        self._flush()
        return self.extract_columns()
```

**How it works:** each report is held until the next line arrives. If the next line starts with spaces, it is the tail and gets joined. If not, the old report is complete, so it goes into the table and the new one is held. The key point is that `clean_report` (line 222) strips leading spaces, so the check for those spaces has to happen **before** cleaning.

**Proof** `[estimate]`: this fix alone raises temp 80.9% → 86.3%, altimeter 74.0% → 79.1%, wind 78.4% → 80.1%.

## 6. Minus signs and loose digits

**Your lines:** 466. **Gold:** `_TEMP` 29-30 and `_number_ratio` 153-156.

**Example:** `-5/-10`, `M5/M1`, `5/M1`. The standard form is `M05/M10`.

**Before:**

```python
        standard_match = re.search(r"\b(M?\d{2})/(M?\d{2})\b", body)
```

**After:** add to `tidy()`, rewriting every form to `M05/M10`:

```python
_TTOK = re.compile(r"^([M-]?)(\d{1,2})/([M-]?)(\d{1,2})$")
def _temp_tok(tok):
    m = _TTOK.match(tok)
    if not m:
        return tok
    a, x, b, y = m.groups()
    return f"{'M' if a else ''}{int(x):02d}/{'M' if b else ''}{int(y):02d}"
# in tidy():  t = " ".join(_temp_tok(tok) for tok in t.split(" "))
```

**Proof** `[estimate]`: temp 80.9% → 82.6% with this fix alone. The form `-3 / -10` (a minus sign and spaces together) still leaves 5 rows out of 5,783.

## Test summary

Synthetic data was generated from the conditions in the README (3 seeds, 17,401 keys in total, the same 5 value columns as your table). I ran your original, the gold, and your handler with all 6 fixes applied `[estimate]`:

| | recovered | unmatched | duplicate rows | wind | vis | ceiling | temp | altimeter |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Yours (original) | 92.1% | 482 | 1,039 | 78.4% | 71.2% | 87.9% | 80.9% | 74.0% |
| Gold | 96.1% | 0 | 0 | 90.2% | 87.5% | 93.6% | 91.7% | 87.8% |
| Yours + 6 fixes | 99.9% | 0 | 0 | 99.9% | 99.8% | 99.9% | 99.8% | 99.1% |

Do not read this table as a predicted score. The generator and the fixes were both written from the same reading of the README, so the fixed version looks better than the gold. The gold faces real data with more variety. The most trustworthy number is **duplicate rows 1,039 → 0**, because it matches the error measured on the real run in the README.

## Where your handler is stronger than the gold

Your handler reads the relay's lines (`msg`, `src`, `ts`) through `ALIASES` and `flatten` (lines 8-21, 173-216), while the gold only looks for `report`, `rawOb`, `metar`, `raw_text`, `line` (lines 322-324) `[inferred]`. You also recover JSON wrapped in several layers of strings (lines 151-159).

## Not compared or not verified

- **`2400` (hour 24):** both handlers return `[]` `[estimate]`. This is 0.2% of the stream.
- **`CALM`:** both return `wind_kt = None`. The README does not give the expected answer, so I do not judge it.
- **Decimal temperature `22.4/14.1`:** `[untested]`.
- **A bulletin with `ZCZC` or a line break inside the heading:** `[untested]`.
- **TEMPO/BECMG, VV, MPS:** your handler already handles them (lines 391-433), so they are not part of the fixes.

## A pattern for later weeks

```python
class Handler:
    def __init__(self):
        self.rows = {}        # key -> last value
        self.pending = None   # a report waiting for its continuation line
    def process(self, raw):
        ...                   # only write into self.rows
        return []
    def finalize(self):
        self._flush()
        return [unpack(k, v) for k, v in self.rows.items()]
```

Rule: **never emit the same key from `process` and then again in `finalize`**, and never emit again when a value changes. Week 1 lost 1,709,876 points to this, week 10 lost 120,680.
