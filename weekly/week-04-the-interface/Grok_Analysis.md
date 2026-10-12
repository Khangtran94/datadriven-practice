# Week 4 – The Interface: handler.py vs gold_submit.py

**Your score:** 0.0000 (#6 of 6, top 100%)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py` (helpers only; full Handler not present in the committed file)

This note compares your submission to the top solution's available helpers. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

The run crashed at record 1,000,000, recovering 0 of 749,978 rows. Architecture (process returns `[]`, finalize emits) is already correct; the gaps are in HL7 field recovery, timezone resolution, value/unit normalization, and patient/test selection.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Crash / unhandled edge cases | Zero recovery; any exception in the hot path kills the whole run. |
| 2 | Encoding characters & HL7 escapes | Field separators, component separators, and `\\S\\` / `\\F\\` are not fixed; many OBX-3 / values become unreadable. |
| 3 | Timezone / DST fold | Offset-less times from two labs; gold rejects ambiguous local hours, you guess. |
| 4 | Value parsing (SN, flags, comparators) | Non-numeric and structured numbers are common; wrong nulls or string values lose cells. |
| 5 | Patient ID selection (PID-3 / PID-2, authority) | Multiple MR forms and issuers; wrong or missing patient_id. |
| 6 | Test code (primary + alternate LOINC) | Codes in component 0 or 3; system identifier must match. |
| 7 | Unit normalization | Bench spellings (`10^3/uL`, `K/uL`, micro sign) and coded elements. |
| 8 | Status / rank / W / U handling | Order-level vs OBX-11; withdrawn and unsolicited statuses. |

---

## 1. Crash / unhandled edge cases

**Your code**
```python
# process L~380
try:
    e = self._parse(raw)
    ...
except Exception:
    pass
return []
```

**Gold code**  
Helpers assume well-formed input after `_message` / `_decode`; no full Handler in the file. Your broad `except` hides bugs that still crash later (or OOM on `self.seen` / `self.groups` at 1 M lines).

**Example input**  
A truncated or double-escaped line that produces a non-hashable key or an infinite loop in `fix_layers` / `split_segments`.

**Your behavior**  
Swallowed exception or memory growth → crash at ~1 M records, 0 rows.

**Gold behavior**  
Strict early returns (`_NONE`, empty sets) keep memory bounded and never raise on bad fields.

**Why it matters**  
Zero score. Any uncaught error or unbounded structure loses the entire stream.

**What to change**  
Remove the blanket `except`. Bound `seen` / `groups` (or use a sliding window). Validate every field before storing.

---

## 2. Encoding characters & HL7 escapes

**Your code**
```python
# hl7u L~40 – only fixed \\\\F\\\\ \\\\S\\\\ \\\\T\\\\ \\\\R\\\\ \\\\E\\\\
def hl7u(s):
    return re.sub(r"\\\\([FSTRE])\\\\", ...)
# split on | / ^ hard-coded; no MSH-1/MSH-2 encoding chars
```

**Gold code**
```python
# _decode L~110
# uses the actual encoding characters from MSH (chars[0..4])
# handles unfinished escapes, \\\\X..\\\\ hex, and empty "" 
```

**Example input**  
`MSH|^~\\\\&|...` with a field containing `\\\\S\\\\` or a custom component separator.

**Your behavior**  
Literal `\\\\S\\\\` left in the code or value; test/unit lookup fails.

**Gold behavior**  
Decodes after splitting on the real separators; returns empty string on bad escape.

**Why it matters**  
“Units as typed”, “test codes 5 ways”, and “enter typed inside a field” all depend on correct decoding.

**What to change**  
Parse MSH-1 / MSH-2 once, then pass the five characters into every `_decode` call. Decode only after splitting.

---

## 3. Timezone / DST fold

**Your code**
```python
# _localize L~130 – simple DST offset, no fold check
def _localize(dt, zone):
    off = (-5 if zone == "E" else -6) + (1 if _is_dst(dt) else 0)
    return (dt - timedelta(hours=off)).replace(tzinfo=timezone.utc)
```

**Gold code**
```python
# _time L~180
a = naive.replace(tzinfo=zone, fold=0)
b = naive.replace(tzinfo=zone, fold=1)
if a.utcoffset() != b.utcoffset():
    return _NONE          # ambiguous local hour → null
```

**Example input**  
Offset-less `202403100200` during the spring-forward hour from the Eastern lab.

**Your behavior**  
Assigns a guessed offset → wrong UTC instant.

**Gold behavior**  
Returns `_NONE` (null `observed_at`).

**Why it matters**  
“Times with no offset” and “times in 5 widths” are large conditions; wrong timestamps lose the cell.

**What to change**  
Use `ZoneInfo` with explicit `fold` check; reject ambiguous hours.

---

## 4. Value parsing (SN, flags, comparators)

**Your code**
```python
# parse_value L~220
if flag in ("<", ">"): return None
if "^" in v:          # take parts[1] or parts[0]
...
return format(d.quantize(...), "f")   # string
```

**Gold code**
```python
# _value L~230
if kind == 'SN':
    if _decode(parts[0]) not in ('', '='): return _NONE
    text = parts[1]
...
return int(number.quantize(Decimal('0.01'), ROUND_HALF_UP) * 100)  # integer cents
```

**Example input**  
OBX-5 = `>^10` (SN) or `10 <` with OBX-8 flag, or `1,234.5`.

**Your behavior**  
May keep a comparator string or return a string `"10.00"`.

**Gold behavior**  
Only pure numbers (or SN with empty/`=` comparator); stores integer scaled by 100.

**Why it matters**  
“Values that are not numbers”, “flags written in the value”, and “decimals as written” lose or mis-format the value cell.

**What to change**  
Honor OBX-2 type; reject any comparator; keep the scaled integer (or format only at emit).

---

## 5. Patient ID selection

**Your code**
```python
# pick_pid L~280
ok = [(p,a,t) for ... if re.fullmatch(r"\\d{8}", p)]
# preference: HOSP+MR, HOSP, empty+MR
```

**Gold code**
```python
# _patient / _ids L~140
# only HOSP+MR (or legacy single-component on PID-2)
# if >1 match → _NO_PATIENT
# returns int or sentinel
```

**Example input**  
PID-3 = `12345678^...^HOSP^MR~87654321^...^RLAB^MR`

**Your behavior**  
May pick the first 8-digit number it likes.

**Gold behavior**  
Only the hospital MR; multiple hospital MRs → null patient.

**Why it matters**  
“MRN in 6 forms” and “MR numbers from 2 issuers” are frequent; wrong patient_id loses the cell.

**What to change**  
Strict authority + type filter; treat multiple matches as null.

---

## 6. Test code (primary + alternate)

**Your code**
```python
# L~340
t = TEST_CODES.get(c0) or TEST_CODES.get(c3)
```

**Gold code**
```python
# _test L~260
for start in (0, 3):
    code = _decode(...)
    system = _decode(...).upper()
    if code in _TEST_CODES and system in ('', 'LN', 'LOINC', 'L', 'LOCAL'):
        return _TEST_CODES[code]
```

**Example input**  
OBX-3 = `LOCAL^...^2345-7^LOINC` or name-only field.

**Your behavior**  
May map on code alone, ignoring system, or miss alternate.

**Gold behavior**  
Requires both code and acceptable system identifier.

**Why it matters**  
“Test codes, 5 ways”, “LOINC as the alternate code”, and “tests named, not coded”.

**What to change**  
Check system component; only accept the six known analytes.

---

## 7. Unit normalization

**Your code**
```python
# norm_unit / _unit_lookup L~250
THOU_RE for x10E3/uL etc.
UNIT_MAP for a few spellings
```

**Gold code**
```python
# _unit L~245
simple = decoded.replace(' ', '').lower()
if simple in _UNIT_CODES or simple.startswith('10^3/ul' + sep):
    return code
```

**Example input**  
`10^3/uL`, `K/uL`, `µmol/L`, or coded `mg/dL^...`.

**Your behavior**  
May leave the raw string or miss the power spelling.

**Gold behavior**  
Canonical index into `_UNITS`.

**Why it matters**  
“Units as typed” and “SI units beside US units”.

**What to change**  
Expand the map and treat the whole `10^3/uL` token as one unit.

---

## 8. Status / rank / W / U

**Your code**
```python
# STATUS_MAP, RANK, OUT_STATUS
# special U handling that can promote preliminary → final
```

**Gold code**
```python
# _STATUS_CODES / _RANK / _STATUSES
# W and U have explicit ranks; only final/preliminary/corrected emitted
```

**Example input**  
OBX-11 empty, OBR-25 = `F`; or a later `W` line.

**Your behavior**  
May emit `W` or keep a preliminary after withdrawal.

**Gold behavior**  
Uses the correct source (OBX-11 preferred) and rank so the withdrawn result disappears.

**Why it matters**  
“Order-level code”, “withdrawn by W”, and “revised by a later line”.

**What to change**  
Prefer OBX-11; apply a strict rank that never lets a lower status overwrite a higher one; drop `W`.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.groups = {}          # (accession, test_idx) → list of candidates
        self.merge = {}           # old MR → kept MR
        self.seen = set()         # message digests (bounded)

    def process(self, raw: str) -> list[dict]:
        # _message → split on real encoding chars → _decode every field
        # extract accession, test, patient, value, unit, observed_at, status
        # store candidate; never return rows
        return []

    def finalize(self) -> list[dict]:
        # apply merges
        # for each key pick the highest-rank, non-truncated, latest candidate
        # format value/unit/status only at emit
        # return the complete list of rows
        return list_of_all_rows
```

This is the architecture already present in your handler and what the scoring harness expects. The remaining work is making every field parser as strict and complete as the gold helpers.
