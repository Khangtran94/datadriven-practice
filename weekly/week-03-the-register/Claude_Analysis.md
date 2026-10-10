# Week 3: The Register: `handler.py` vs `gold_submit.py`

**Your score:** 0.7693 · **Rank:** #6 of 14 (top 43%) · **Points:** +40
**Records recovered:** 786,280 of 900,971 · **Work per record:** 3.0x median · **Statements:** 233
**Context:** each smart meter reports its energy and its register (running total) every half hour. Billing needs 1 clean row per meter per half hour: `meter_id, interval_end, usage_kwh, register_kwh, quality`. The real read replaces an estimate, and usage for register-only meters is the difference from the previous half hour, taken in interval order.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

---

## Impact ranking

Stream-loss figures are rough: share of stream × share not recovered, per the README. Conditions overlap.

| # | Area | ~Stream lost | Gap vs gold |
|---|---|---:|---|
| 1 | Emit timing and merge ranks | ~4.5% fill-in, plus CDC and late effects | First emission is final; no correction rank |
| 2 | Register → usage | ~3.8% (`usage_kwh` wrong 105,002) | Arrival-order diff, no 30-minute check |
| 3 | JSON recovery | ~6% (quoted, CDC, broken, truncated) | One `loads` plus a brace slice; `before` beats `after` |
| 4 | Null spellings | ~5.0% | 8 spellings, and null strings win slots |
| 5 | Start-stamped intervals | ~4.7% | No `*_start` keys, no +30 min |
| 6 | Numbers and Wh | ~3.4% | Decimal commas fail; sibling unit ignored (gold too) |
| 7 | Meter ids | ~1.7%, plus dropped rows | 6 aliases, exact `M-\d{7}` |
| 8 | Quality flags | ~1.4% (`quality` wrong 68,109) | 8-code map, numeric flags unmapped |
| 9 | Rounding and output type | unknown | `HALF_UP` / `Decimal` vs gold's `HALF_EVEN` / strings |
| 10 | CDT/CST labels | ~5.9% | Beyond gold: neither handler parses the label |

---

## 1. Emit timing and merge ranks

**Your code**
```python
# L250–251
SNAP = True
EMIT_UPDATES = False
# L328–331: after the first emission for (meter, bucket) nothing is sent again
if (m, b) in self.sent and (not EMIT_UPDATES or self.sent[(m, b)] == sig):
    return []
return [out]
# L335–336
def finalize(self): return []
# L18, L287–288: RANK = {actual: 2, estimated: 1}; usage = latest non-null in the bucket
```

**Gold code**
```python
# L682: rank = 3 if is_correction(dicts) else 2 if actual else 1 if estimated else 0
# L690–709 _merge: lower rank ignored; higher rank overwrites but keeps old values where new is null;
#                  same rank: later non-null cells win
# L711–727 process: only merges, returns []
# L729–772 finalize: sort per meter, fill usage, emit all rows
```

**Example input**
An estimate (`"q":"SUB"`, usage 1.100) for M-0000001 at 10:30 arrives first. The real read (`"q":"A"`, usage 1.250) arrives later for the same interval.

**Your behavior**
The estimate is emitted and frozen. The actual is merged internally but never re-sent, so `quality` and `usage_kwh` end up wrong. Inside a snapped bucket, `_merge` also takes the latest non-null usage whatever its quality (L287), so an estimate's value can land on an actual row.

**Gold behavior**
Everything is held. Actual beats estimated, and a CDC/update line (rank 3) beats both. One final row is written in `finalize`.

**Why it matters**
Fill-in is 10% of the stream with 55% recovered. The same buffering is what makes the register diffs in section 2 possible.

**What to change**
Buffer everything in `process`, resolve rank and merge in `finalize`, and give correction/CDC lines a rank above actual. Drop the `SNAP` and `EMIT_UPDATES` switches.

---

## 2. Register → usage

**Your code**
```python
# L294–307 _usage: sorted insert by bucket; diff against whatever came before, at arrival time
if row["usage_kwh"] is None and reg is not None and i > 0:
    d = reg - lst[i - 1][1]
    if d >= 0: row["usage_kwh"] = d
```

**Gold code**
```python
# L729–761 finalize: per meter, items sorted by interval_end
if ts - prev_ts == 1800:
    delta = reg - prev_reg
    if delta >= 0: rec[0] = fmt3(delta)
# a missing register resets prev_reg / prev_ts
```

**Example input**
- Registers for 10:00 and 11:00 with no 10:30 row.
- Lines arriving as 10:30, then 10:00.

**Your behavior**
- The 11:00 diff covers two intervals, so the usage is wrong.
- A row whose predecessor arrives later keeps `usage_kwh = None`, because it was already emitted and is never revisited.

**Gold behavior**
- Usage for 11:00 stays null across the gap.
- Diffs always run in interval order, whatever order lines arrived in.

**Why it matters**
Running totals are 20% of the stream, and `usage_kwh` is wrong 105,002 times.

**What to change**
Compute diffs in `finalize` over the sorted intervals. Accept a diff only when the previous register is exactly 30 minutes earlier, and reject negative diffs.

---

## 3. JSON recovery

**Your code**
```python
# L59–81 extract_json: json.loads, then text[first "{" : last "}"], dict only
# L84–95 flatten: setdefault, so the FIRST key wins
```

**Gold code**
```python
# L444–473 parse_raw: loads -> repair_json_text (L360–375) -> close_truncated (L385–418) -> kv_fallback (L421–441)
#                     a str result is decoded again
# L476–503 expand_strings: JSON strings nested in fields
# L562–582 unwrap_record: WRAP_KEYS = message, payload, body, data, record, after, new, ...
# L585–612 iter_records: lists such as records / readings / items / rows / events
```

**Example input**
- Quoted: `"{\"meter_id\":\"M-0000001\",\"kwh\":1.25,...}"`
- CDC: `{"op":"u","before":{"meter_id":"M-0000001","kwh":1.25},"after":{"meter_id":"M-0000001","kwh":1.30}}`
- Truncated: `{"meter_id":"M-0000001","interval_end":"2026-10-04T10:30:00Z","kwh":1.2`
- A string value with a literal tab inside

**Your behavior**
- The quoted line decodes to a string, and the brace slice keeps the backslashes, so it fails.
- In the CDC line `flatten` reads `before` first, and `setdefault` keeps it, so you return the stale 1.25.
- The truncated line has no `}` and is dropped.
- The tab line fails strict parsing.

**Gold behavior**
- It decodes the string a second time and merges `after` over the outer dict, so CDC gives 1.30.
- It closes the truncated object.
- For the tab line it falls through to the regex `kv_fallback`.

**Why it matters**
Quoted JSON is 2.0% of the stream (7% recovered), CDC 2.5% (50%), broken JSON 2.0% (34%), truncated 0.5% (1%). The CDC case silently returns stale values.

**What to change**
Decode up to three times, unwrap `after`/`payload`/`body`, and add `strict=False`. Close truncated objects, but drop the last unterminated token: a cut mid-number such as `1.2` for `1.25` would be a wrong value.

---

## 4. Null spellings

**Your code**
```python
# L31
NULL_STRINGS = {"", "null", "none", "n/a", "na", "nan", "-", "--"}
# L103–104 canonical: first alias wins even if it holds a null string
if out.get(c) is None:
    out[c] = v
```

**Gold code**
```python
# L9–13 NULL_SPELLINGS: 26 spellings (nil, undefined, missing, nat, unknown, nulo, nichts, <null>, #n/a, ...)
# L146–153 is_null
# L520–531 lookup: skips null values, so the next alias is tried
```

**Example input**
`{"usage":"N/A","kwh":1.25}` and `{"q":"nulo"}`

**Your behavior**
`"N/A"` takes the `kwh` slot first, so `usage_kwh` becomes `None` even though a valid value follows. `"nulo"` is not recognized as null (here it happens to map to `None` anyway).

**Gold behavior**
The null is skipped and 1.25 is used.

**Why it matters**
Nulls spelled as strings are 15% of the stream (67% recovered), the single largest condition after key order.

**What to change**
Apply one shared `is_null()` before a value is stored in `canonical()`, so later aliases can fill the slot. Extend the spelling set.

---

## 5. Start-stamped intervals

**Your code**
```python
# L21: end-only keys
"interval_end": ["interval_end","intervalend","end","ts","timestamp","period_end","event_time"]
# L208–221 bucket_interval: snaps any time up to the next :00 / :30
```

**Gold code**
```python
# L57–63 START_KEYS (interval_start, period_start, start_time, ...)
# L656–666
end_v, end_k = lookup_norm(dicts, END_KEYS)
if end_v is None:
    end_v, end_k = lookup_norm(dicts, START_KEYS); is_start = end_v is not None
# L343–357 align_end: +30 minutes when is_start, then align to :00 / :30
```

**Example input**
`{"meter":"M-0000001","interval_start":"2026-10-04T10:00:00Z","kwh":1.2}`

**Your behavior**
`interval_start` is not an alias, so there is no `interval_end` and `clean` returns `None`: the row is dropped. If the line used `ts` instead, it would be read as an end and overwrite the previous half hour.

**Gold behavior**
`interval_end` is `2026-10-04T10:30:00Z`.

**Why it matters**
Stamped-at-the-start is 5.0% of the stream and only 7% was recovered.

**What to change**
Add start keys as a separate field and shift by 30 minutes. Remove the `SNAP` toggle (your notes say `SNAP = False` matched the sample, but the graded file has `SNAP = True`; check which was meant).

---

## 6. Numbers and Wh

**Your code**
```python
# L34 VAL_RE and L163–195 norm_dec: Decimal(str(v)) on "1.234,5" or "1,5" raises -> None
# L48–56 key_unit: unit read from the key name; L172–180: or from a suffix in the value
```

**Gold code**
```python
# L171–222 parse_number
if "," in s and "." in s:          # whichever separator comes last is the decimal point
    ...
elif "," in s:                     # decimal comma if 1-3 digits follow it
    ...
# L83–86, L100–102: Wh keys; L186–191: unit suffix in the value
# no sibling "unit" field
```

**Example input**
`"kwh":"1.234,5"` and `{"usage":1500,"unit":"Wh"}`

**Your behavior**
- The first becomes `None`.
- The second is read as 1500 kWh, which is 1000× too high.

**Gold behavior**
- The first becomes `1234.5`.
- The second is also 1500: gold ignores a sibling `unit` as well.

**Why it matters**
Wh in place of kWh is 8% of the stream (71% recovered) and numbers as strings 5% (78%).

**What to change**
Port the separator logic from `parse_number`. Beyond gold: the README says a head-end may send "the raw count with a unit beside it", so read `unit`/`uom` too, and check it against the sample.

---

## 7. Meter ids

**Your code**
```python
# L17, L20
METER_RE = re.compile(r"M-\d{7}")
"meter_id": ["meter_id","meterid","meter",'id',"mid","msn"]
# L112–116: must be a str that fully matches after strip().upper()
```

**Gold code**
```python
# L33–43 METER_KEYS: about 50 aliases (serial, device_id, esiid, nmi, id_medidor, zaehler_id, ...)
# L115 METER_RE = (?<![A-Z0-9])M-?(\d{5,7})(?!\d)
# L249–265: remove spaces and underscores, search, zero-pad to M-xxxxxxx; bare digits are padded too
# L621–652: falls back to nested meter dicts, then any non-bookkeeping value
```

**Example input**
`" m1234567 "`, `{"id_medidor":"M-0000001"}`, `{"meter":{"id":"M-0000001"}}`

**Your behavior**
All three are dropped: a missing dash fails the full match, and the other two have no matching key.

**Gold behavior**
All three resolve to an `M-xxxxxxx` id.

**Why it matters**
`meter_id` is part of the key, so a miss loses the whole row (114,691 missed). Padding and casing is 6.0% of the stream (71% recovered).

**What to change**
Strip non-alphanumerics, search `M-?\d{5,7}`, zero-pad to seven digits, and scan nested dicts. Extend the alias list from the sample.

---

## 8. Quality flags

**Your code**
```python
# L7–16 QUALITY_MAP: a, actual, sub, e, est, estimated, estimate, substituted
# L198–205: numbers go through str() into the map
```

**Gold code**
```python
# L15–23 ACTUAL / ESTIMATED sets (act, measured, verified, interpolated, imputed, ...)
# L225–246 parse_quality: 1 -> actual, 2 -> estimated; substring "actual", "estimat", "subst"; "s" -> estimated
```

**Example input**
`"q": 1`, `"q": "ACT"`, `"q": "interpolated"`, `"q": "PENDING"`

**Your behavior**
`1` becomes `"1"`, which is not in the map, so `None`. `"act"` and `"interpolated"` also return `None`. `"PENDING"` is `None`, which is correct.

**Gold behavior**
`actual`, `actual`, `estimated`, `None`.

**Why it matters**
`quality` is wrong 68,109 times. Read flags per maker are 6.0% of the stream (77% recovered).

**What to change**
Port the sets and the numeric rule, and keep workflow states such as PENDING and HOLD as `None`.

---

## 9. Rounding and output type

**Your code**
```python
# L4, L190–195
Decimal("0.001"), rounding=ROUND_HALF_UP     # values are returned as Decimal objects
```

**Gold code**
```python
# L7, L156–168 fmt3: ROUND_HALF_EVEN, returned as a three-decimal string such as "1.250"
```

**Example input**
`"kwh": 0.0005`

**Your behavior**
`0.001` (half-up), as a `Decimal`.

**Gold behavior**
`"0.000"` (half-even), as a string.

**Why it matters**
Unknown. Ties at the fourth decimal are rare but real, and the output type may matter to the grader. This could account for part of the 105,002 wrong `usage_kwh`. It is a guess; the sample feedback would show it quickly.

**What to change**
Use `ROUND_HALF_EVEN` and a three-decimal string, then compare against the sample.

---

## 10. CDT/CST labels (beyond gold)

**Your code**
```python
# L149–160: fromisoformat(...replace("Z","+00:00")); naive -> UTC; a trailing "CDT" raises -> None
```

**Gold code**
```python
# L285–340 parse_datetime: the same behavior; "... CDT" matches no format, so the row is dropped
```

**Example input**
`"2026-11-01 01:30:00 CDT"` and `"2026-11-01 01:30:00 CST"`

**Your behavior**
Both rows are dropped.

**Gold behavior**
Both rows are dropped as well.

**Why it matters**
Local time is 8% of the stream with 26% recovered, and the fall-back night makes 01:30 occur twice (only the label tells the two apart). No handler here recovers it, so it is the largest open gain.

**What to change**
Map `CDT` to UTC-5 and `CST` to UTC-6, convert to UTC before keying, and treat unlabeled naive times as `America/Chicago` (the README says meter clocks keep the utility's wall time).

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}                            # (meter, interval_end_utc) -> [usage, register, quality, rank]

    def process(self, raw):
        obj = parse_raw(raw)                      # loads -> repair -> close_truncated -> kv fallback; multi-decode
        for rec in iter_records(obj):             # unwrap envelopes; prefer CDC `after`
            row = clean_record(rec)               # is_null, aliases, units, start +30m, tz label -> UTC
            if row:
                self.merge(row)                   # rank: correction > actual > estimated; fill nulls only
        return []                                 # never emit here

    def finalize(self):
        for meter, items in sorted_by_meter(self.held):
            prev = None
            for end, rec in items:                # interval order, not arrival order
                if rec.usage is None and prev and end - prev.end == 1800 and rec.reg >= prev.reg:
                    rec.usage = rec.reg - prev.reg
                prev = rec if rec.reg is not None else None
        return [as_row(k, r) for k, r in self.held.items()]   # one row per (meter, interval)
```
