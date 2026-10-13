# Week 3: The Register: `handler.py` vs `gold_submit.py`

**Your score:** 0.7693 · **Rank:** #6 of 14 (top 43%) · **Points:** +40
**Records recovered:** 786,280 of 900,971 · **Work per record:** 3.0x median · **Statements:** 233
**Context:** each smart meter reports its energy and its register (running total) every half hour. Billing needs 1 clean row per meter per half hour: `meter_id, interval_end, usage_kwh, register_kwh, quality`. The real read replaces an estimate, and usage for register-only meters is the difference from the previous half hour's register, taken in interval order.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

**Evidence tags:** `[measured]` from the README · `[estimate]` from my local run of your handler, the gold file and the proposed handler on hand-built inputs (not the real feed) · `[inferred]` from reading the code · `[untested]` proposed code I could not run.

> **How this file works.** Every section shows your code verbatim (**Before**), the proposed code (**After**), a plain-language **How it works**, and a **Proof** table where I ran your handler, the gold file and the proposed handler on the same input. The complete proposed handler is at the end.

## Proof summary `[estimate]`

- 26 hand-built scenarios (one or more per section below): **your handler passes 6, gold passes 23, the proposed handler passes 26.** I wrote the scenarios and the proposed handler together, so treat this as a check of the ideas, not a score prediction.
- On a clean, in-order stream of 20,000 lines (200 meters × 100 intervals, half of them register-only), your handler, gold and the proposed handler returned **identical rows**, so the changes only affect the problem cases.
- The scenarios where gold also fails are marked in the tables: a sibling `unit` field, and `CDT`/`CST` labels.

---

## Impact ranking

Stream-loss figures are rough: share of stream × share not recovered, per the README. Conditions overlap.

| # | Area | ~Stream lost | Gap vs gold |
|---|---|---:|---|
| 1 | Emit timing and merge ranks | ~4.5% fill-in `[measured]`, plus CDC and late effects | First emission is final |
| 2 | Register → usage | ~3.8%; `usage_kwh` wrong 105,002 `[measured]` | Arrival-order diff, no 30-minute check |
| 3 | JSON recovery | ~6% (quoted, CDC, broken, truncated) | One `loads` plus a brace slice; `before` beats `after` |
| 4 | Null spellings | ~5.0% | 8 spellings, and null strings win slots |
| 5 | Start-stamped intervals | ~4.7% | No `*_start` keys, no +30 min |
| 6 | Numbers and Wh | ~3.4% | Decimal commas fail; sibling unit ignored (gold too) |
| 7 | Meter ids | ~1.7%, plus dropped rows | Exact `M-\d{7}` match |
| 8 | Quality flags | ~1.4%; `quality` wrong 68,109 `[measured]` | 8-code map, numeric flags unmapped |
| 9 | Rounding and output type | unknown | `HALF_UP` / `Decimal` vs gold's `HALF_EVEN` / strings |
| 10 | CDT/CST labels | ~5.9% | Beyond gold: neither handler parses the label |

---

## 1. Emit timing and merge ranks

**Your code**: `process` returns a row the first time it sees a `(meter, bucket)` and nothing after that (`EMIT_UPDATES = False`). `finalize` returns `[]`.

**Gold code**: `gold_submit.py` L690–709, L711–727, L729–772: `process` only merges into one held record (lower rank ignored, higher rank overwrites but keeps old values where the new one is null), and `finalize` emits everything.

**Example input**: an estimate (`"quality":"SUB"`, usage 1.100) for a meter and interval, then the real read (`"A"`, usage 1.250) for the same interval. And the reverse: the real read, then a replayed estimate.

**Your behavior**: with the estimate first, the estimate is emitted and frozen; the real read is merged internally but never sent. With the real read first, your rank rule correctly keeps it.

**Gold behavior**: the real read wins in both orders.

**Why it matters**: fill-in is 10% of the stream with 55% recovered `[measured]`. The same buffering makes the register diffs in section 2 possible.

**Before** (`handler.py`)
```python
 18  RANK = {"actual": 2, "estimated": 1, None: 0}
...
250  SNAP = True           
251  EMIT_UPDATES = False   
...
284      def _merge(self, m, b):
285          reads = self.reads[(m, b)]
286          rs = [reads[t] for t in sorted(reads)]
287          usage = next((r["usage_kwh"] for r in reversed(rs) if r["usage_kwh"] is not None), None)
288          reg = next((r["register_kwh"] for r in reversed(rs) if r["register_kwh"] is not None), None)
289          qs = {r["quality"] for r in rs}
290          quality = "actual" if "actual" in qs else ("estimated" if "estimated" in qs else None)
291          return {"meter_id": m, "interval_end": b,
292                  "usage_kwh": usage, "register_kwh": reg, "quality": quality}
...
328              if (m, b) in self.sent and (not EMIT_UPDATES or self.sent[(m, b)] == sig):
329                  return []
330              self.sent[(m, b)] = sig
331              return [out]
...
335      def finalize(self):
336          return []
```

**After**
```python
RANK = {"actual": 2, "estimated": 1, None: 0}

class Handler:                                           # excerpt: the process() method
    def process(self, raw):
        try:
            rec = parse_raw(raw)
            row = clean_record(rec) if rec is not None else None
            if row:
                cur = self.held.setdefault((row["meter_id"], row["end"]), [None, None, None])
                if RANK[row["quality"]] >= RANK[cur[2]]:      # a real read replaces an estimate; a replayed estimate never replaces it
                    for i, k in enumerate(("usage", "register")):
                        if row[k] is not None:
                            cur[i] = row[k]
                    cur[2] = row["quality"] or cur[2]
                else:                                         # lower rank: only fill what is still empty
                    for i, k in enumerate(("usage", "register")):
                        if cur[i] is None:
                            cur[i] = row[k]
        except Exception:
            pass
        return []
```

**How it works**: `process` never emits. It keeps one entry per `(meter, interval)` and applies one rule: a read of equal or higher rank replaces the stored values (actual beats estimated), while a lower-rank read, such as a replayed estimate, only fills values that are still empty. Everything is written once in `finalize`.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| fill-in: estimate, then real read -> usage | `1.25` | ✘ 1.1 | ✔ 1.25 | ✔ 1.25 |
| fill-in: estimate, then real read -> quality | `actual` | ✘ estimated | ✔ actual | ✔ actual |
| fill-in: real read, then replayed estimate -> usage | `1.25` | ✔ 1.25 | ✔ 1.25 | ✔ 1.25 |
| fill-in: real read, then replayed estimate -> quality | `actual` | ✔ actual | ✔ actual | ✔ actual |

---

## 2. Register → usage

**Your code**: a sorted insert by bucket, with the diff taken against whatever register came before, at arrival time, whatever the gap.

**Gold code**: `gold_submit.py` L729–761: sort each meter's rows by interval, take the diff only if the previous row is exactly 1,800 seconds earlier, reset the chain when a register is missing.

**Example input**: registers for 10:30 then 10:00 (arriving out of order); and registers for 10:00 and 11:00 with no 10:30 row.

**Your behavior**: the 10:30 row arrives first with no previous register and is emitted with `usage_kwh = None`; it is never revisited. In the gap case the 11:00 diff spans two intervals and gives 2.0 instead of nothing.

**Gold behavior**: usage 1.25 for the out-of-order case, and null across the gap.

**Why it matters**: running totals are 20% of the stream and `usage_kwh` was wrong 105,002 times `[measured]`.

**Before** (`handler.py` L294–307)
```python
294      def _usage(self, m, b, row):
295          lst = self.regs.setdefault(m, [])
296          i = find_pos(lst, b)
297          reg = row["register_kwh"]
298          if row["usage_kwh"] is None and reg is not None and i > 0:
299              d = reg - lst[i - 1][1]
300              if d >= 0:
301                  row["usage_kwh"] = d
302          if reg is not None:
303              if i < len(lst) and lst[i][0] == b:
304                  lst[i] = (b, reg)
305              else:
306                  lst.insert(i, (b, reg))
307          return row
```

**After**
```python
class Handler:                                           # excerpt: the finalize() method
    def finalize(self):
        out, by_meter = [], {}
        for (meter, end), cell in self.held.items():
            by_meter.setdefault(meter, []).append((end, cell))
        for meter, items in by_meter.items():
            prev_end = prev_reg = None
            for end, cell in sorted(items, key=lambda x: x[0]):       # interval order, not arrival order
                usage, reg, quality = cell
                if usage is None and reg is not None and prev_reg is not None and end - prev_end == timedelta(minutes=30) and reg >= prev_reg:
                    usage = reg - prev_reg
                prev_end, prev_reg = (end, reg) if reg is not None else (None, None)
                out.append({
                    "meter_id": meter,
                    "interval_end": end.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "usage_kwh": f"{usage:.3f}" if usage is not None else None,
                    "register_kwh": f"{reg:.3f}" if reg is not None else None,
                    "quality": quality,
                })
        return out
```

**How it works**: because nothing is emitted until `finalize`, all registers are known by then. Each meter's intervals are sorted, and usage is the difference from the previous interval's register only if that interval is exactly 30 minutes earlier and the diff is not negative.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| register: arrives 10:30 before 10:00 -> usage 10:30 | `1.25` | ✘ None | ✔ 1.25 | ✔ 1.25 |
| register: 10:00 then 11:00 (10:30 missing) -> usage 11:00 | `None` | ✘ 2.0 | ✔ None | ✔ None |

> Null across a gap is my reading of the README ("the difference from the previous half hour's register") and what gold does. Check it against the sample `[inferred]`.

---

## 3. JSON recovery

**Your code**: `json.loads`, then a slice from the first `{` to the last `}`, dict only. `flatten` uses `setdefault`, so the first key wins.

**Gold code**: `gold_submit.py` L444–473 (loads, repair, close truncated objects, regex fallback; decode again when the result is a string), L476–503 (JSON strings nested in fields), L562–582 (unwrap `after`, `payload`, `body`...), L585–612 (lists of records).

**Example input**: a quoted line (`"{\"meter_id\":...}"`); a CDC line `{"op":"u","before":{...,"kwh":1.25},"after":{...,"kwh":1.30}}`; a queue envelope `{"id":"q1","body":"{...}"}`; a line with a literal tab inside a string.

**Your behavior**: the quoted line decodes to a string and then fails (the slice keeps the backslashes); the envelope has no recognized fields on the outside; the tab line fails strict parsing; in the CDC line `flatten` reads `before` first and `setdefault` keeps it, so you return the stale 1.25.

**Gold behavior**: all four are recovered, with the CDC value 1.30.

**Why it matters**: quoted JSON is 2.0% of the stream (7% recovered), CDC 2.5% (50%), broken JSON 2.0% (34%), truncated 0.5% (1%) `[measured]`. The CDC case silently returns stale values.

**Before** (`handler.py` L59–81, L84–95)
```python
 59  def extract_json(raw):
 60      if not isinstance(raw,str):
 61          return None
 62      raw = raw.strip()
 63      try: 
 64          record = json.loads(raw)
 65          if isinstance(record, dict):
 66              return record
 67      except json.JSONDecodeError:
 68          pass
 69      
 70      ### Recover JSON from surronding text:
 71      start = raw.find('{')
 72      end = raw.rfind('}')
 73      if start == -1 or end <= start:
 74          return None
 75      try:
 76          record = json.loads(raw[start:end+1])
 77          if isinstance(record, dict):
 78              return record
 79      except json.JSONDecodeError:
 80          return None
 81      return None
...
 84  def flatten(obj, depth=0):
 85      """Pull fields out of one or two levels of sub-objects."""
 86      flat = {}
 87  
 88      for k, v in obj.items():
 89          if isinstance(v, dict) and depth < 2:
 90              for k2, v2 in flatten(v, depth + 1).items():
 91                  flat.setdefault(k2, v2)
 92          else:
 93              flat.setdefault(k, v)
 94  
 95      return flat
```

**After**
```python
def parse_raw(raw, depth=0):
    obj = raw.strip().lstrip("\ufeff") if isinstance(raw, str) else raw
    for _ in range(4):                                   # JSON written as a quoted string (maybe twice)
        if not isinstance(obj, str):
            break
        try:
            obj = json.loads(obj, strict=False)
        except ValueError:                               # log prefix, junk after the object, trailing commas
            a, b = obj.find("{"), obj.rfind("}")
            if a < 0 or b <= a:
                return None
            try:
                obj = json.loads(re.sub(r",\s*([}\]])", r"\1", obj[a:b + 1]), strict=False)
            except ValueError:
                return None
    if not isinstance(obj, dict):
        return None
    if isinstance(obj.get("after"), dict):               # change-data-capture: the row is the AFTER image
        outer = {k: v for k, v in obj.items() if k not in ("before", "after")}
        return {**outer, **obj["after"]}
    has_time = any(LOOKUP.get(norm_key(k)) in ("end", "start") for k in flatten(obj))
    if not has_time and depth < 4:                       # queue envelope: the record sits inside a wrapper field
        for k in WRAPPERS:
            if isinstance(obj.get(k), (str, dict)):
                inner = parse_raw(obj[k], depth + 1)
                if inner:
                    return inner
    return obj

def flatten(obj, depth=0):
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat
```

**How it works**: a string is decoded up to four times (`strict=False` also accepts a tab inside a string), falling back to a brace slice with trailing commas removed. If the line has an `after` image, that image is the row. If nothing on the outside looks like a read, the record is looked for inside wrapper fields (`body`, `message`, `payload`...).

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| json: quoted string | `1.25` | ✘ <no row> | ✔ 1.25 | ✔ 1.25 |
| json: CDC envelope (before 1.25, after 1.30) | `1.3` | ✘ 1.25 | ✔ 1.3 | ✔ 1.3 |
| json: queue envelope with body string | `1.25` | ✘ <no row> | ✔ 1.25 | ✔ 1.25 |
| json: literal tab inside a string | `1.25` | ✘ <no row> | ✔ 1.25 | ✔ 1.25 |

> Truncated lines (cut mid-line) are not handled by this version. Gold closes the open object; if you do the same, drop the last unfinished value, because a cut such as `1.2` for `1.25` would be a wrong number `[untested]`.

---

## 4. Null spellings

**Your code**: 8 spellings, checked only inside `norm_dec`; `canonical` stores the first value found for a field even when it is `"N/A"`.

**Gold code**: `gold_submit.py` L9–13 (26 spellings), L146–153 (`is_null`), L520–531 (a lookup that skips null values).

**Example input**: `{"usage":"N/A","kwh":1.25}`.

**Your behavior**: `"N/A"` takes the usage slot, so `usage_kwh` becomes `None` even though a valid `kwh` follows.

**Gold behavior**: the null is skipped and 1.25 is used.

**Why it matters**: nulls spelled as strings are 15% of the stream (67% recovered) `[measured]`.

**Before** (`handler.py` L31, L98–109)
```python
 31  NULL_STRINGS = {"", "null", "none", "n/a", "na", "nan", "-", "--"}
...
 98  def canonical(obj):
 99      out, units, extra = {}, {}, {}
100      for k, v in flatten(obj).items():
101          c = LOOKUP.get(_normalize_key_name(k))
102          if c is not None:
103              if out.get(c) is None:
104                  out[c] = v
105                  if c in ("kwh", "register"):
106                      units[c] = key_unit(k)
107          elif k in SEQ_KEYS:
108              extra[k] = v
109      return out, units, extra
```

**After**
```python
NULLS = {"", "null", "none", "n/a", "na", "nan", "nil", "undefined", "missing", "unknown", "-", "--", "n.a.", "#n/a", "<null>"}

def is_null(v):
    return v is None or (isinstance(v, str) and v.strip().lower() in NULLS)

def canonical(rec):                                      # field -> (value, original key); null spellings never take a slot
    out = {}
    for k, v in flatten(rec).items():
        f = LOOKUP.get(norm_key(k))
        if f and f not in out and not is_null(v) and not isinstance(v, (dict, list)):
            out[f] = (v, k)
    return out
```

**How it works**: one `is_null()` is applied before a value is stored, so a null spelling never takes the slot and a later valid alias can fill it.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| nulls: usage 'N/A' beside a valid kwh | `1.25` | ✘ None | ✔ 1.25 | ✔ 1.25 |

---

## 5. Start-stamped intervals

**Your code**: only end-style keys (`interval_end`, `end`, `ts`, `timestamp`, `period_end`, `event_time`); times are snapped up to the next :00 or :30.

**Gold code**: `gold_submit.py` L57–63 (start keys), L656–666, L343–357 (`align_end`: add 30 minutes for a start key, then align).

**Example input**: `{"meter":"M-0000012","interval_start":"2026-10-04T10:00:00Z","kwh":1.2}`.

**Your behavior**: `interval_start` is not an alias, so there is no end time and the row is dropped.

**Gold behavior**: the interval ends at 10:30.

**Why it matters**: stamped-at-the-start is 5.0% of the stream and only 7% was recovered `[measured]`.

**Before** (`handler.py` L21, L208–221)
```python
 21      "interval_end": ["interval_end", "intervalend", "end", "ts", "timestamp", "period_end",'event_time'],
...
208  def bucket_interval(ts):
209      try:
210          dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
211      except (ValueError, AttributeError):
212          return None
213      base = dt.replace(minute=0, second=0, microsecond=0)
214      off = dt - base
215      if off == timedelta(0):
216          b = base
217      elif off <= timedelta(minutes=30):
218          b = base + timedelta(minutes=30)
219      else:
220          b = base + timedelta(hours=1)
221      return b
```

**After**
```python
def half_hour_end(dt, is_start):
    if is_start:                                         # stamped at the start of the half hour: the interval ends 30 min later
        dt = dt + timedelta(minutes=30)
    base = dt.replace(minute=0, second=0, microsecond=0)
    off = dt - base
    if off == timedelta(0):
        return base
    return base + (timedelta(minutes=30) if off <= timedelta(minutes=30) else timedelta(hours=1))

def clean_record(rec):
    c = canonical(rec)
    meter = clean_meter(c["meter"][0]) if "meter" in c else None
    if meter is None:
        return None
    if "end" in c:
        when, is_start = clean_time(c["end"][0]), False
    elif "start" in c:
        when, is_start = clean_time(c["start"][0]), True
    else:
        return None
    if when is None:
        return None
    sib = c["unit"][0] if "unit" in c else None
    return {
        "meter_id": meter,
        "end": half_hour_end(when, is_start),
        "usage": clean_energy(*c["usage"], sib) if "usage" in c else None,
        "register": clean_energy(*c["register"], sib) if "register" in c else None,
        "quality": clean_quality(c["quality"][0]) if "quality" in c else None,
    }
```

**How it works**: start-style keys are read as a separate field. When only a start exists, 30 minutes are added so the row lands on the half hour it describes, then the usual alignment applies. The `SNAP`/`EMIT_UPDATES` switches are gone.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| start-stamped: interval_start 10:00 -> end 10:30 | `1.2` | ✘ <no row> | ✔ 1.2 | ✔ 1.2 |

> Your notes say `SNAP = False` matched the sample, but the graded file has `SNAP = True`. The alignment here follows gold; check which one the sample prefers.

---

## 6. Numbers and Wh

**Your code**: `Decimal(str(v))` on text such as `"1.234,5"` raises, so the value becomes `None`. The unit comes from the key name or a suffix in the value only.

**Gold code**: `gold_submit.py` L171–222 (`parse_number`: the last separator is the decimal point; a lone comma is decimal if 1–3 digits follow), L83–86, L100–102 (Wh keys), L186–191 (unit suffix). It does not read a sibling `unit` field.

**Example input**: `"kwh":"1.234,5"`; `{"usage":1500,"unit":"Wh"}`; `"usage":"1500 Wh"`; `"usage_wh":1500`.

**Your behavior**: the first is `None`; the second is read as 1500 kWh, which is 1000× too high; the last two are correct.

**Gold behavior**: the first is 1234.5; the second is also 1500 (it ignores a sibling `unit`); the last two are correct.

**Why it matters**: Wh in place of kWh is 8% of the stream (71% recovered), numbers as strings 5% (78%) `[measured]`.

**Before** (`handler.py` L34, L48–56, L163–195)
```python
 34  VAL_RE = re.compile(r"([-+]?[\d.,]*\d(?:[eE][-+]?\d+)?)\s*([A-Za-z]*)")
...
 48  def key_unit(k):
 49      nk = _normalize_key_name(k)
 50      if nk.endswith("mwh"):
 51          return "mwh"
 52      if nk.endswith("kwh"):
 53          return "kwh"
 54      if nk.endswith("wh"):
 55          return "wh"
 56      return None
...
163  def norm_dec(v, field_unit=None):
164      """Normalize energy value to Decimal kWh, 3 decimal places."""
165      if v is None or isinstance(v, bool):
166          return None
167      unit = None
168      if isinstance(v, str):
169          s = v.strip()
170          if s.lower() in NULL_STRINGS:
171              return None
172          m = VAL_RE.fullmatch(s)
173          if not m:
174              return None
175          text, suffix = m.group(1), m.group(2)
176          if suffix:
177              unit = norm_unit(suffix)
178              if unit is None:
179                  return None
180          v = text
181      elif not isinstance(v, (int, float)):
182          return None
183      unit = unit or norm_unit(field_unit) or "kwh"
184      try:
185          d = Decimal(str(v))
186      except InvalidOperation:
187          return None
188      if not d.is_finite() or d < 0:
189          return None
190      return (
191          d * UNIT_FACTOR[unit]
192      ).quantize(
193          Decimal("0.001"),
194          rounding=ROUND_HALF_UP
195      )
```

**After**
```python
def to_number(s):                                        # "1.234,5"  "1,5"  "1,234.5"
    s = s.strip()
    if "," in s and "." in s:
        s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", "") if re.fullmatch(r"[-+]?\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
    return Decimal(s)

def key_unit(k):
    nk = norm_key(k)
    return "mwh" if nk.endswith("mwh") else "kwh" if nk.endswith("kwh") else "wh" if nk.endswith("wh") else None

def clean_energy(v, key, sibling_unit):                  # -> Decimal kWh with 3 decimals, or None
    try:
        if isinstance(v, bool):
            return None
        unit = None
        if isinstance(v, str):
            m = re.fullmatch(r"\s*([-+]?[\d.,]*\d)\s*([A-Za-z]*)\s*", v)
            if not m:
                return None
            v, suffix = m.groups()
            if suffix:
                unit = suffix.lower()
                if unit not in UNIT_FACTOR:
                    return None
            d = to_number(v)
        else:
            d = Decimal(str(v))
        unit = unit or key_unit(key) or (str(sibling_unit).strip().lower() if sibling_unit else None) or "kwh"
        if unit not in UNIT_FACTOR or not d.is_finite() or d < 0:
            return None
        return (d * UNIT_FACTOR[unit]).quantize(Decimal("0.001"), rounding=ROUND_HALF_EVEN)
    except (InvalidOperation, ValueError):
        return None
```

**How it works**: the unit is taken from a suffix in the value first, then from the key name, then from a sibling `unit`/`uom` field, defaulting to kWh. Wh and MWh are converted to kWh. Text numbers are read with the "last separator is the decimal point" rule.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| numbers: '1.234,5' | `1234.5` | ✘ None | ✔ 1234.5 | ✔ 1234.5 |
| units: usage 1500 with unit 'Wh' | `1.5` | ✘ 1500.0 | ✔ 1.5 | ✘ 1500.0 |
| units: '1500 Wh' in the value | `1.5` | ✔ 1.5 | ✔ 1.5 | ✔ 1.5 |
| units: key usage_wh | `1.5` | ✔ 1.5 | ✔ 1.5 | ✔ 1.5 |

> The sibling `unit` field goes beyond gold. The README says a head-end may send "the raw count with a unit beside it", so it is worth checking against the sample.

---

## 7. Meter ids

**Your code**: 6 aliases, and a full match on `M-\d{7}` after trimming and uppercasing.

**Gold code**: `gold_submit.py` L33–43 (about 50 aliases), L115, L249–265: spaces and underscores removed, `M-?(\d{5,7})` searched, zero-padded; falls back to nested meter dicts.

**Example input**: `" m0000017 "`; `"M0000018"` (no dash); `{"meter":{"id":"M-0000019"}}`.

**Your behavior**: the first two are dropped (neither id has the dash, so the full match fails; trimming and uppercasing alone would have handled a dashed id). The nested id is found by `flatten`.

**Gold behavior**: all three resolve.

**Why it matters**: `meter_id` is part of the key, so a miss loses the whole row (114,691 missed) `[measured]`. Padding and casing is 6.0% of the stream (71% recovered).

**Before** (`handler.py` L17, L20, L112–116)
```python
 17  METER_RE = re.compile(r"M-\d{7}")
 20      "meter_id": ["meter_id", "meterid", "meter", 'id',"mid", "msn"],
...
112  def norm_meter(v):
113      if not isinstance(v, str):
114          return None
115      v = v.strip().upper()
116      return v if METER_RE.fullmatch(v) else None
```

**After**
```python
def clean_meter(v):
    if not isinstance(v, str):
        return None
    m = METER_RE.fullmatch(re.sub(r"[\s_]+", "", v).upper())
    return "M-" + m.group(1) if m else None
```

**How it works**: remove spaces and underscores, uppercase, then accept `M` + an optional dash + 7 digits and rebuild it as `M-xxxxxxx`.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| meter: ' m0000017 ' (lowercase, spaces) | `1.25` | ✘ <no row> | ✔ 1.25 | ✔ 1.25 |
| meter: missing dash 'M0000018' | `1.25` | ✘ <no row> | ✔ 1.25 | ✔ 1.25 |
| meter: id inside a sub-object | `1.25` | ✔ 1.25 | ✔ 1.25 | ✔ 1.25 |

> Gold also zero-pads shorter numbers (5 or 6 digits). I did not copy that guess; add it only if the sample shows such ids `[untested]`.

---

## 8. Quality flags

**Your code**: 8 spellings; numbers go through `str()` straight into the map.

**Gold code**: `gold_submit.py` L15–23 (sets), L225–246 (`parse_quality`: 1 is actual, 2 is estimated, plus substring checks).

**Example input**: `"quality": 1` (a number), `"ACT"`, `"interpolated"`, `"PENDING"`.

**Your behavior**: `1`, `ACT` and `interpolated` all become `None`; `PENDING` is `None`, which is correct.

**Gold behavior**: `actual`, `actual`, `estimated`, `None`.

**Why it matters**: `quality` was wrong 68,109 times `[measured]`. Read flags per maker are 6.0% of the stream (77% recovered).

**Before** (`handler.py` L7–16, L198–205)
```python
  7  QUALITY_MAP = {
  8      "a": "actual",
  9      "actual": "actual",
 10      "sub": "estimated",
 11      "e": "estimated",
 12      "est": "estimated",
 13      "estimated": "estimated",
 14      "estimate": "estimated",
 15      "substituted": "estimated",
 16  }
...
198  def norm_quality(v):
199      if v is None:
200          return None
201      if isinstance(v, (int, float)):
202          v = str(v)
203      if not isinstance(v, str):
204          return None
205      return QUALITY_MAP.get(v.strip().lower())
```

**After**
```python
ACTUAL = {"a", "act", "actual", "m", "meter", "metered", "measured", "read", "r", "1"}

ESTIMATED = {"e", "est", "estimate", "estimated", "s", "sub", "substituted", "interpolated", "imputed", "i", "2"}

def clean_quality(v):
    s = str(v).strip().lower()
    return "actual" if s in ACTUAL else "estimated" if s in ESTIMATED else None
```

**How it works**: two sets of spellings (including the numeric 1 and 2) decide the label. Anything else, such as a workflow state like PENDING or HOLD, stays `None`.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| quality: 1 | `actual` | ✘ None | ✔ actual | ✔ actual |
| quality: 'ACT' | `actual` | ✘ None | ✔ actual | ✔ actual |
| quality: 'interpolated' | `estimated` | ✘ None | ✔ estimated | ✔ estimated |
| quality: 'PENDING' | `None` | ✔ None | ✔ None | ✔ None |

> The spellings are my best guesses plus the ones the README names. Extend the sets from the codes you see in the sample `[untested]`.

---

## 9. Rounding and output type

**Your code**: `ROUND_HALF_UP`, and values are returned as `Decimal` objects.

**Gold code**: `gold_submit.py` L7, L156–168 (`fmt3`): `ROUND_HALF_EVEN`, returned as a three-decimal string such as `"1.250"`.

**Example input**: `"kwh": 0.0005`.

**Your behavior**: `0.001` (half-up).

**Gold behavior**: `0.000` (half-even).

**Why it matters**: unknown. Ties at the fourth decimal are rare but real, and the output type may matter to the grader `[inferred]`.

**Before** (`handler.py` L4, L190–195)
```python
  4  from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
...
190      return (
191          d * UNIT_FACTOR[unit]
192      ).quantize(
193          Decimal("0.001"),
194          rounding=ROUND_HALF_UP
195      )
```

**After**: `clean_energy` (section 6) rounds with `ROUND_HALF_EVEN`, and `finalize` (section 2) writes `f"{usage:.3f}"` strings.

**How it works**: ties round to the even digit, and values leave as fixed three-decimal text like the top submission.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| rounding: 0.0005 (tie) | `0.0` | ✘ 0.001 | ✔ 0.0 | ✔ 0.0 |

---

## 10. CDT/CST labels (beyond gold)

**Your code**: `fromisoformat(...)` fails on a trailing `CDT` or `CST`, and a time with no label is read as UTC.

**Gold code**: `gold_submit.py` L285–340 (`parse_datetime`): the same; a label matches no format and the row is dropped.

**Example input**: `"2026-11-01 01:30:00 CDT"` and the same time with `CST`.

**Your behavior**: both rows are dropped.

**Gold behavior**: both rows are dropped as well.

**Why it matters**: local time is 8% of the stream with 26% recovered `[measured]`, and the fall-back night makes 01:30 occur twice, so only the label tells the two apart. No handler here recovers it.

**Before** (`handler.py` L118–160)
```python
118  def norm_time(time_check):
119      if time_check is None or isinstance(time_check, bool):
120          return None
121      # Unix timestamp
122      if isinstance(time_check, (int, float)):
123          try:
124              num = float(time_check)
125              # Treat large timestamps as milliseconds
126              if num > 1e11:
127                  num /= 1000
128              dt = datetime.fromtimestamp(num, tz=timezone.utc)
129              return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
130          except (OSError, ValueError, OverflowError):
131              return None
132      if not isinstance(time_check, str):
133          return None
134      time_check = time_check.strip()
135  
136      if not time_check:
137          return None
138      # Numeric string -> Unix timestamp
139      try:
140          num = float(time_check)
141          # Treat large timestamps as milliseconds
142          if num > 1e11:
143              num /= 1000
144          dt = datetime.fromtimestamp(num, tz=timezone.utc)
145          return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
146      except (ValueError, OSError, OverflowError):
147          pass
148      # ISO 8601
149      try:
150          dt = datetime.fromisoformat(
151              time_check.replace("Z", "+00:00")
152          )
153          # No timezone -> assume UTC
154          if dt.tzinfo is None:
155              dt = dt.replace(tzinfo=timezone.utc)
156          else:
157              dt = dt.astimezone(timezone.utc)
158          return dt.strftime("%Y-%m-%dT%H:%M:%SZ")
159      except ValueError:
160          return None
```

**After**
```python
def _to_utc(dt, tz):
    if tz is None:                                       # wall time of the utility
        a, b = dt.replace(tzinfo=CHICAGO, fold=0), dt.replace(tzinfo=CHICAGO, fold=1)
        return None if a.utcoffset() != b.utcoffset() else a.astimezone(timezone.utc)
    t = tz.upper()
    off = {"Z": 0, "UTC": 0, "GMT": 0, "CDT": -300, "CST": -360}.get(t)
    if off is None:
        digits = t[1:].replace(":", "")
        off = (1 if t[0] == "+" else -1) * (int(digits[:2]) * 60 + int(digits[2:]))
    return dt.replace(tzinfo=timezone(timedelta(minutes=off))).astimezone(timezone.utc)

def clean_time(v):                                       # -> aware UTC datetime or None
    try:
        if isinstance(v, bool):
            return None
        if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
            v = float(v)
        if isinstance(v, (int, float)):
            n = float(v)
            n = n / 1e3 if n >= 1e11 else n              # milliseconds -> seconds
            return datetime.fromtimestamp(n, tz=timezone.utc)
        m = TIME_RE.fullmatch(str(v).strip())
        if not m:
            return None
        y, mo, d, hh, mm, ss, tz = m.groups()
        return _to_utc(datetime(int(y), int(mo), int(d), int(hh), int(mm), int(ss or 0)), tz)
    except (ValueError, OverflowError, OSError):
        return None
```

**How it works**: `CDT` means UTC-5 and `CST` UTC-6, so the two 01:30s become 06:30Z and 07:30Z. A time with no label is treated as the utility's wall time (Chicago); if that clock reading is ambiguous the time is null.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| local time: '2026-11-01 01:30:00 CDT' | `1.25` | ✘ <no row> | ✔ 1.25 | ✘ <no row> |
| local time: '2026-11-01 01:30:00 CST' | `1.25` | ✘ <no row> | ✔ 1.25 | ✘ <no row> |

> That unlabeled times mean Chicago wall time is my reading of the README ("meter clocks keep the utility's wall time") `[inferred]`.

---

## Recommended pattern

`process()` collects and ranks, `finalize()` sorts and emits once. The full proposed handler (every After above, assembled) follows. Run it against the sample before submitting.

<details>
<summary>Complete proposed <code>handler.py</code></summary>

```python
import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN
from zoneinfo import ZoneInfo

CHICAGO = ZoneInfo("America/Chicago")
NULLS = {"", "null", "none", "n/a", "na", "nan", "nil", "undefined", "missing", "unknown", "-", "--", "n.a.", "#n/a", "<null>"}
ACTUAL = {"a", "act", "actual", "m", "meter", "metered", "measured", "read", "r", "1"}
ESTIMATED = {"e", "est", "estimate", "estimated", "s", "sub", "substituted", "interpolated", "imputed", "i", "2"}
UNIT_FACTOR = {"wh": Decimal("0.001"), "kwh": Decimal(1), "mwh": Decimal(1000)}
WRAPPERS = ("body", "message", "payload", "data", "record", "msg")
ALIASES = {
    "meter": {"meterid", "meter", "id", "mid", "msn"},
    "end": {"intervalend", "end", "ts", "timestamp", "periodend", "eventtime"},
    "start": {"intervalstart", "start", "periodstart", "starttime"},
    "usage": {"usagekwh", "kwh", "usage", "energykwh", "energy", "usagewh", "energywh", "wh", "usagemwh", "mwh"},
    "register": {"registerkwh", "register", "reg", "totalkwh", "cumulative", "registerwh", "regwh", "totalwh", "registermwh"},
    "quality": {"quality", "q", "readtype", "status", "flag"},
    "unit": {"unit", "uom", "units"},
}
LOOKUP = {a: f for f, names in ALIASES.items() for a in names}
TIME_RE = re.compile(r"(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2}))?(?:\.\d+)?\s*(Z|UTC|GMT|CDT|CST|[+-]\d{2}:?\d{2})?", re.I)
METER_RE = re.compile(r"M-?(\d{7})")


def norm_key(k):
    return re.sub(r"[^a-z0-9]", "", str(k).lower())


def is_null(v):
    return v is None or (isinstance(v, str) and v.strip().lower() in NULLS)


# ---- 1. read one line, however it was wrapped -----------------------------------------
def parse_raw(raw, depth=0):
    obj = raw.strip().lstrip("\ufeff") if isinstance(raw, str) else raw
    for _ in range(4):                                   # JSON written as a quoted string (maybe twice)
        if not isinstance(obj, str):
            break
        try:
            obj = json.loads(obj, strict=False)
        except ValueError:                               # log prefix, junk after the object, trailing commas
            a, b = obj.find("{"), obj.rfind("}")
            if a < 0 or b <= a:
                return None
            try:
                obj = json.loads(re.sub(r",\s*([}\]])", r"\1", obj[a:b + 1]), strict=False)
            except ValueError:
                return None
    if not isinstance(obj, dict):
        return None
    if isinstance(obj.get("after"), dict):               # change-data-capture: the row is the AFTER image
        outer = {k: v for k, v in obj.items() if k not in ("before", "after")}
        return {**outer, **obj["after"]}
    has_time = any(LOOKUP.get(norm_key(k)) in ("end", "start") for k in flatten(obj))
    if not has_time and depth < 4:                       # queue envelope: the record sits inside a wrapper field
        for k in WRAPPERS:
            if isinstance(obj.get(k), (str, dict)):
                inner = parse_raw(obj[k], depth + 1)
                if inner:
                    return inner
    return obj


def flatten(obj, depth=0):
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat


def canonical(rec):                                      # field -> (value, original key); null spellings never take a slot
    out = {}
    for k, v in flatten(rec).items():
        f = LOOKUP.get(norm_key(k))
        if f and f not in out and not is_null(v) and not isinstance(v, (dict, list)):
            out[f] = (v, k)
    return out


# ---- 2. one function per field ------------------------------------------------------------
def clean_meter(v):
    if not isinstance(v, str):
        return None
    m = METER_RE.fullmatch(re.sub(r"[\s_]+", "", v).upper())
    return "M-" + m.group(1) if m else None


def _to_utc(dt, tz):
    if tz is None:                                       # wall time of the utility
        a, b = dt.replace(tzinfo=CHICAGO, fold=0), dt.replace(tzinfo=CHICAGO, fold=1)
        return None if a.utcoffset() != b.utcoffset() else a.astimezone(timezone.utc)
    t = tz.upper()
    off = {"Z": 0, "UTC": 0, "GMT": 0, "CDT": -300, "CST": -360}.get(t)
    if off is None:
        digits = t[1:].replace(":", "")
        off = (1 if t[0] == "+" else -1) * (int(digits[:2]) * 60 + int(digits[2:]))
    return dt.replace(tzinfo=timezone(timedelta(minutes=off))).astimezone(timezone.utc)


def clean_time(v):                                       # -> aware UTC datetime or None
    try:
        if isinstance(v, bool):
            return None
        if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
            v = float(v)
        if isinstance(v, (int, float)):
            n = float(v)
            n = n / 1e3 if n >= 1e11 else n              # milliseconds -> seconds
            return datetime.fromtimestamp(n, tz=timezone.utc)
        m = TIME_RE.fullmatch(str(v).strip())
        if not m:
            return None
        y, mo, d, hh, mm, ss, tz = m.groups()
        return _to_utc(datetime(int(y), int(mo), int(d), int(hh), int(mm), int(ss or 0)), tz)
    except (ValueError, OverflowError, OSError):
        return None


def half_hour_end(dt, is_start):
    if is_start:                                         # stamped at the start of the half hour: the interval ends 30 min later
        dt = dt + timedelta(minutes=30)
    base = dt.replace(minute=0, second=0, microsecond=0)
    off = dt - base
    if off == timedelta(0):
        return base
    return base + (timedelta(minutes=30) if off <= timedelta(minutes=30) else timedelta(hours=1))


def to_number(s):                                        # "1.234,5"  "1,5"  "1,234.5"
    s = s.strip()
    if "," in s and "." in s:
        s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
    elif "," in s:
        s = s.replace(",", "") if re.fullmatch(r"[-+]?\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
    return Decimal(s)


def key_unit(k):
    nk = norm_key(k)
    return "mwh" if nk.endswith("mwh") else "kwh" if nk.endswith("kwh") else "wh" if nk.endswith("wh") else None


def clean_energy(v, key, sibling_unit):                  # -> Decimal kWh with 3 decimals, or None
    try:
        if isinstance(v, bool):
            return None
        unit = None
        if isinstance(v, str):
            m = re.fullmatch(r"\s*([-+]?[\d.,]*\d)\s*([A-Za-z]*)\s*", v)
            if not m:
                return None
            v, suffix = m.groups()
            if suffix:
                unit = suffix.lower()
                if unit not in UNIT_FACTOR:
                    return None
            d = to_number(v)
        else:
            d = Decimal(str(v))
        unit = unit or key_unit(key) or (str(sibling_unit).strip().lower() if sibling_unit else None) or "kwh"
        if unit not in UNIT_FACTOR or not d.is_finite() or d < 0:
            return None
        return (d * UNIT_FACTOR[unit]).quantize(Decimal("0.001"), rounding=ROUND_HALF_EVEN)
    except (InvalidOperation, ValueError):
        return None


def clean_quality(v):
    s = str(v).strip().lower()
    return "actual" if s in ACTUAL else "estimated" if s in ESTIMATED else None     # PENDING, HOLD ... -> unknown


def clean_record(rec):
    c = canonical(rec)
    meter = clean_meter(c["meter"][0]) if "meter" in c else None
    if meter is None:
        return None
    if "end" in c:
        when, is_start = clean_time(c["end"][0]), False
    elif "start" in c:
        when, is_start = clean_time(c["start"][0]), True
    else:
        return None
    if when is None:
        return None
    sib = c["unit"][0] if "unit" in c else None
    return {
        "meter_id": meter,
        "end": half_hour_end(when, is_start),
        "usage": clean_energy(*c["usage"], sib) if "usage" in c else None,
        "register": clean_energy(*c["register"], sib) if "register" in c else None,
        "quality": clean_quality(c["quality"][0]) if "quality" in c else None,
    }


# ---- 3. hold everything per (meter, interval); resolve and emit in finalize ------------------
RANK = {"actual": 2, "estimated": 1, None: 0}


class Handler:
    def __init__(self):
        self.held = {}                                   # (meter, end) -> [usage, register, quality]

    def process(self, raw):
        try:
            rec = parse_raw(raw)
            row = clean_record(rec) if rec is not None else None
            if row:
                cur = self.held.setdefault((row["meter_id"], row["end"]), [None, None, None])
                if RANK[row["quality"]] >= RANK[cur[2]]:      # a real read replaces an estimate; a replayed estimate never replaces it
                    for i, k in enumerate(("usage", "register")):
                        if row[k] is not None:
                            cur[i] = row[k]
                    cur[2] = row["quality"] or cur[2]
                else:                                         # lower rank: only fill what is still empty
                    for i, k in enumerate(("usage", "register")):
                        if cur[i] is None:
                            cur[i] = row[k]
        except Exception:
            pass
        return []                                             # never emit here

    def finalize(self):
        out, by_meter = [], {}
        for (meter, end), cell in self.held.items():
            by_meter.setdefault(meter, []).append((end, cell))
        for meter, items in by_meter.items():
            prev_end = prev_reg = None
            for end, cell in sorted(items, key=lambda x: x[0]):       # interval order, not arrival order
                usage, reg, quality = cell
                if usage is None and reg is not None and prev_reg is not None and end - prev_end == timedelta(minutes=30) and reg >= prev_reg:
                    usage = reg - prev_reg
                prev_end, prev_reg = (end, reg) if reg is not None else (None, None)
                out.append({
                    "meter_id": meter,
                    "interval_end": end.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "usage_kwh": f"{usage:.3f}" if usage is not None else None,
                    "register_kwh": f"{reg:.3f}" if reg is not None else None,
                    "quality": quality,
                })
        return out
```

</details>

## Checklist

1. **Buffer, then emit once.** When reads can be corrected or arrive late, the final value is only known in `finalize`.
2. **Sort before differencing.** Take register diffs in interval order and only across exactly one interval.
3. **Skip null spellings before choosing a value**, so a later valid alias can fill the slot.
4. **Convert times to UTC before keying**, and keep the zone label.
5. **Test with hand-built lines for every condition in the README**, including the order the lines arrive in.
