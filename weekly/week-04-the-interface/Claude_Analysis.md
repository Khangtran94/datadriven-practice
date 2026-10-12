# Week 4: The Interface: `handler.py` vs `gold_submit.py`

**Your score:** 0.0000 · **Rank:** #6 of 6 (top 100%) · **Points:** +0
**Records recovered:** 0 of 749,978 · **Run:** crashed at record 1,000,000 · **Work per record:** 1.8x median (1.77× vs the winner's 1.71×) · **Statements:** 355
**Offline score on the same stream:** 0.7883, which would have ranked #2 `[measured, platform feedback]`
**Context:** a hospital interface engine logs each HL7 lab-result message as 1 JSON line. The quality team needs 1 row per result: `accession, test, patient_id, value, unit, observed_at, status`.

**Evidence tags:** `[measured]` from the README or platform feedback · `[inferred]` from reading the code · `[estimate]` from my local test on synthetic data · `[not available]` code that is not in the repo · `[untested]` proposed code I could not run.

> `gold_submit.py` in this folder ends at line 287 (`_test`). It has helper functions only: no `Handler` class, no `process`, no `finalize`. Gold comparisons below cover those helpers.

---

## Why your score was 0

- **The run hit the memory limit.** It read all 1,000,000 records, then was stopped before `finalize()` returned any rows, so nothing was scored `[measured]`.
- **What the handler kept.** A candidate dict for every line (`self.groups`, L415), a fingerprint of every line (`self.seen`, L336–339), and about 750k row dicts built at the end (L453–468). Projected over the full stream that is about 1,238 MB against a 512 MB limit `[measured]`.
- **The sample hid it.** The sample showed 19/512 MB, but it measured only 300 lines, which is mostly Python itself. The result used to say "timeout" and now says memory.
- **It was not a speed problem.** Work per record was 1.77× the median and the winner's was 1.71×. The read took under 2 minutes. Work per record counts what the code does per line, not what it keeps.
- **The pattern was right, the state was not.** `process` returns `[]` and `finalize` emits, which is the intended design. The handler just held too much before `finalize`.

## Impact ranking

| # | Area | Penalty | Gap vs gold |
|---|---|---|---|
| 1 | Unbounded state → out of memory | **[measured]** score 0 (0.7883 offline) | Gold helpers return small ints `[inferred]`; Handler class `[not available]` |
| 2 | Merged chart numbers never applied | `[inferred]`, 7.0% of stream | Gold's merge handling `[not available]` |
| 3 | Test mapping and OBX choice | `[inferred]`, 15% + 12% + 9% + 12% | Gold's `_test` checks the coding system |
| 4 | Collection time sources | `[inferred]`, 12% + 8% + 25% | Gold's caller `[not available]` |
| 5 | Flags written in the value | `[inferred]`, 20% | Neither visible code strips the flag |
| 6 | DST and patient-id ambiguity | `[inferred]`, 12% + 11% + 12% | Gold nulls ambiguous cases |

Sections 2 to 6 are upside, not the cause of the 0. The offline score of 0.7883 shows the logic is strong. They are ranked by README stream share and are not measured penalties.

---

## 1. Unbounded state → out of memory (the cause of the 0)

**Your code**
```python
# handler.py L322, L336–339: a digest of every line is kept
# handler.py L402–409, L415: one 11-key dict per surviving line
# handler.py L418, L453–468: process returns []; finalize builds ~750k row dicts at once
```

**Gold code**
```python
# gold_submit.py L12–19, L177, L238, L263: helpers return small ints
_STATUS_CODES = {'P': 1, 'W': 2, 'F': 3, 'C': 4, 'U': 5}
_NONE = -(1 << 63);  _NO_PATIENT = (1 << 32) - 1
return (delta.days * 86400 + delta.seconds) * 1000000 + delta.microseconds   # µs time
return int(number.quantize(...) * 100)                                      # value in cents
```
How gold stores and emits `[not available]`.

**Example input**
The full log: more than 1,000,000 lines for 749,978 results. The 300-line sample passes.

**Your behavior**
Every line adds a dict and a digest to memory, and nothing is emitted until `finalize`. At 1,000,000 lines it reached about 1,238 MB against 512 MB `[measured]`. With `process` returning `[]`, a stop before `finalize` loses everything.

**Gold behavior**
Helpers return ints for value, time, patient, test, unit and status, which suggests compact per-result state `[inferred]`.

**Why it matters**
This is the only measured penalty: the whole score. It also hides every other condition behind 0%.

### Where the memory went `[estimate, my reproduction on a synthetic stream of 997,500 lines / 750,000 results]`

| Part of your handler | Memory | Share |
|---|---:|---:|
| Candidate dicts kept for every line (`self.groups`) | ~949 MB | 77% |
| Fingerprint of every line (`self.seen`) | ~91 MB | 7% |
| ~750k output row dicts built in `finalize` | ~200 MB | 16% |
| **Peak** | **1,239 MB** | vs the 512 MB limit |

The platform measured 1,238 MB, so my reproduction matches its figure.

### The idea in plain words

Your code works like a filing cabinet that keeps a copy of every sheet it ever received and sorts them at the end. The cabinet grows with the number of lines read. The fix is one note per key, updated as each new line arrives. Memory then grows with the number of results (750k), and each note is much smaller than a dict.

### Before: your current code (verbatim from `handler.py`)

State and fingerprint (L319–324, L336–339):
```python
319  class Handler:
320      def __init__(self):
321          self.groups = {}
322          self.seen = set()
323          self.merge = {}
324          self.n = 0
...
336          digest = hashlib.md5(s.encode("utf-8", "ignore")).digest()
337          if digest in self.seen:
338              return None
339          self.seen.add(digest)
```

One dict per line, kept forever (L402–418):
```python
402          return {
403              "key": (acc, test),
404              "acc": acc, "test": test, "pid": pid, "val": val,
405              "unit": norm_unit(g(obx, 6)),
406              "obs": fmt_ts(parse_ts(g(obr, 7).split("^")[0], zone)),
407              "st": st, "ts": parse_ts(g(msh, 6), zone),
408              "trunc": trunc, "seq": self.n,
409          }
410  
411      def process(self, raw):
412          try:
413              e = self._parse(raw)
414              if e is not None:
415                  self.groups.setdefault(e.get("key"), []).append(e)
416          except Exception:
417              pass
418          return []  # everything is emitted once, in finalize()
```

Everything built at the end (L453–468):
```python
453      def finalize(self):
454          rows = []
455          for entries in self.groups.values():
456              w = self._resolve(entries)
457              if w is None:
458                  continue
459              rows.append({
460                  "accession": w["acc"],
461                  "test": w["test"],
462                  "patient_id": self._final_pid(w["pid"]),
463                  "value": w["val"],
464                  "unit": w["unit"],
465                  "observed_at": w["obs"],
466                  "status": w["st"] if w["st"] in OUT_STATUS else None,
467              })
468          return rows
```

### After: proposed code

The helper functions (L1–317) stay as they are. Replace the `Handler` class (from L318 on) with the code below. Parsing logic is unchanged; only how state is stored and emitted differs. `_parse` is shown in full.

```python
# ------------------------------------------------------------------ handler
# Memory fix: keep a few packed bytes per (accession, test) key instead of one dict per line.
import struct

_PACK = struct.Struct("<qIBBIqqH")        # ts_us, seq, status, trunc, pid, value_cents, obs_s, unit_idx (36 bytes)
TS, SEQ, ST, TRUNC, PID, VAL, OBS, UNIT = range(8)
NO_TS, NO_PID, NO_NUM, NO_UNIT = -(1 << 62), 0xFFFFFFFF, -(1 << 62), 0xFFFF
S_NONE, S_PRELIM, S_W, S_FINAL, S_CORR, S_U = range(6)
ST_CODE = {None: S_NONE, "preliminary": S_PRELIM, "W": S_W, "final": S_FINAL,
           "corrected": S_CORR, "U": S_U}
ST_NAME = {v: k for k, v in ST_CODE.items()}
RANK_BY_CODE = (0, 1, 2, 3, 4, 0)         # same order as RANK in the original handler
EPOCH = datetime(1970, 1, 1, tzinfo=timezone.utc)
ONE_US = timedelta(microseconds=1)


def _win_key(r):                          # same ordering the original _resolve used for the winner
    return (not r[TRUNC], RANK_BY_CODE[r[ST]], r[TS], r[SEQ])


def _resolve(items):
    """Same rules as the original Handler._resolve, on packed tuples."""
    items = sorted(items, key=lambda r: (r[TS], r[SEQ]))
    cands, last = [], None
    for e in items:
        if e[ST] == S_U:
            if e[VAL] != NO_NUM or last is None:
                c = e[:ST] + (S_FINAL,) + e[ST + 1:]
            elif last[ST] == S_PRELIM:
                c = (e[TS], e[SEQ], S_FINAL) + last[TRUNC:]
            else:
                continue
            cands.append(c)
            last = c
            continue
        cands.append(e)
        if e[VAL] != NO_NUM and e[ST] != S_W:
            last = e
    return max(cands, key=_win_key) if cands else None


MAX_KEEP = 6                              # real keys have a few lines; beyond this we prune


def _reduce(items):
    """Keep what can still decide the answer for this key (all distinct entries while there are few)."""
    uniq = {}
    for r in items:                       # an exact re-send adds nothing: keep only its latest copy
        uniq[r[:SEQ] + r[SEQ + 1:]] = r
    items = list(uniq.values())
    if len(items) <= MAX_KEEP:
        return items
    keep = {}                             # many lines for one key: keep only the entries that can still matter
    plain = [r for r in items if r[ST] != S_U]
    if plain:                                                   # best candidate so far
        keep[max(plain, key=_win_key)] = 1
    valued = [r for r in plain if r[VAL] != NO_NUM and r[ST] != S_W]
    if valued:                                                  # latest result with a value (a U line inherits it)
        keep[max(valued, key=lambda r: (r[TS], r[SEQ]))] = 1
    for has_value in (True, False):                             # latest U line with / without a value
        us = [r for r in items if r[ST] == S_U and (r[VAL] != NO_NUM) == has_value]
        if us:
            keep[max(us, key=lambda r: (r[TS], r[SEQ]))] = 1
    return list(keep)


class Handler:
    def __init__(self):
        self.state = {}       # (accession, test) -> bytes: a few packed entries, never one per line
        self.units = []       # distinct unit strings, referenced by index
        self.unit_ix = {}
        self.merge = {}
        self.n = 0

    def _unit_index(self, u):
        if u is None:
            return NO_UNIT
        i = self.unit_ix.get(u)
        if i is None:
            i = self.unit_ix[u] = len(self.units)
            self.units.append(u)
        return i

    # -- parse one log line into (key, packed entry) or None.  Parsing logic is unchanged
    #    from the original; only the output form and the removal of the line fingerprint differ.
    def _parse(self, raw):
        ex = extract(raw)
        if ex is None:
            return None
        msg, trunc, conn = ex
        i = msg.find("MSH|")
        if i < 0:
            return None
        s = fix_layers(msg[i:])
        segs = split_segments(s)
        parsed, obxs = {}, []
        for k, seg in enumerate(segs):
            f = seg.lstrip("\ufeff \t").split("|")
            if trunc and k == len(segs) - 1:
                f = f[:-1]
            name = f[0].strip().upper() if f else ""
            if name == "OBX":
                obxs.append(f)
            elif name and name not in parsed:
                parsed[name] = f

        msh = parsed.get("MSH")
        if not msh or len(msh) < 11:
            return None
        if "ORU" not in g(msh, 8).upper():
            return None
        if g(msh, 10).split("^")[0].strip().upper() != "P":
            return None

        pid = pick_pid(parsed.get("PID"))

        mrg = parsed.get("MRG")
        if mrg and pid and not trunc:
            for old, a, _t in _cx(g(mrg, 1)):
                if re.fullmatch(r"\d{8}", old) and a in ("", "HOSP") and old != pid:
                    self.merge[old] = pid

        obr = parsed.get("OBR")
        if not obr or not obxs:
            return None
        acc = g(obr, 3).split("^")[0].strip().upper()
        if not re.fullmatch(r"[A-Z0-9][A-Z0-9_-]{2,31}", acc):
            return None

        obx, test, code = None, None, ""
        for f in obxs:
            comps = g(f, 3).split("^")
            c0 = comps[0].strip().upper()
            c3 = comps[3].strip().upper() if len(comps) > 3 else ""
            t = TEST_CODES.get(c0) or TEST_CODES.get(c3)
            if t:
                obx, test, code = f, t, c0
                break
        if obx is None:
            obx = obxs[0]
            code = g(obx, 3).split("^")[0].strip().upper()
            if not EMIT_UNMAPPED_TESTS:
                return None
            if not code:
                return None

        zone = sender_zone(g(msh, 2), g(msh, 3), acc)
        tok = g(obx, 11).split("^")[0].strip().upper()
        if not tok:
            tok = g(obr, 25).split("^")[0].strip().upper()
        st = STATUS_MAP.get(tok)

        val = None if st == "W" else parse_value(g(obx, 5), g(obx, 8)) if g(obx, 5) else None
        self.n += 1
        ts = parse_ts(g(msh, 6), zone)
        obs = parse_ts(g(obr, 7).split("^")[0], zone)
        rec = (
            (ts - EPOCH) // ONE_US if ts else NO_TS,
            self.n,
            ST_CODE[st],
            1 if trunc else 0,
            int(pid) if pid else NO_PID,
            int(val.replace(".", "")) if val is not None else NO_NUM,   # "95.20" -> 9520 cents
            int((obs - EPOCH).total_seconds()) if obs else NO_NUM,
            self._unit_index(norm_unit(g(obx, 6))),
        )
        return (acc, test), rec

    def process(self, raw):
        try:
            parsed = self._parse(raw)
            if parsed is not None:
                key, rec = parsed
                blob = self.state.get(key)
                items = list(_PACK.iter_unpack(blob)) if blob else []
                items.append(rec)
                self.state[key] = b"".join(_PACK.pack(*r) for r in _reduce(items))
        except Exception:
            pass
        return []                                 # everything is emitted once, in finalize()

    def _final_pid(self, p):
        if not APPLY_MERGES or p is None:
            return p
        seen = set()
        while p in self.merge and p not in seen:
            seen.add(p)
            p = self.merge[p]
        return p

    def finalize(self):
        rows, state, units = [], self.state, self.units
        while state:
            (acc, test), blob = state.popitem()   # free each key's state as its row is built
            w = _resolve(list(_PACK.iter_unpack(blob)))
            if w is None:
                continue
            pid = "%08d" % w[PID] if w[PID] != NO_PID else None
            val = "%d.%02d" % divmod(w[VAL], 100) if w[VAL] != NO_NUM else None
            obs = (EPOCH + timedelta(seconds=w[OBS])).strftime("%Y-%m-%dT%H:%M:%SZ") if w[OBS] != NO_NUM else None
            st = ST_NAME[w[ST]]
            rows.append({
                "accession": acc,
                "test": test,
                "patient_id": self._final_pid(pid),
                "value": val,
                "unit": units[w[UNIT]] if w[UNIT] != NO_UNIT else None,
                "observed_at": obs,
                "status": st if st in OUT_STATUS else None,
            })
        return rows
```

### How it works

1. **One packed note per key, not one dict per line.** A 36-byte `struct` replaces the 11-key dict (about 538 B). A key usually has 1 to 3 lines, so it stays tiny.
2. **Reconcile on arrival.** `_reduce` keeps the entries that can still change the answer for the key, plus the one a `U` line needs (the last entry with a value). While a key has up to 6 distinct entries, every entry is kept, so nothing is lost.
3. **No line fingerprints.** A re-sent message resolves to the same winner anyway, so `self.seen` only cost memory.
4. **Smaller `finalize`.** `popitem()` frees each key's state as its row is built, so state and rows do not pile up together.
5. **Same rules.** `_resolve` is your original logic on small tuples. Parsing, units, times and patient ids are unchanged, and `APPLY_MERGES` stays `False` here (section 2 changes that).

### Proof `[estimate]`

Synthetic stream: 997,500 lines, 750,000 keys, with revisions, replays and exact re-sends. Not real data.

| Handler | Peak after reading | Peak after `finalize` | Rows |
|---|---:|---:|---|
| Before | 1,035 MB | **1,239 MB** | 750,000 |
| After (returns a list) | 232 MB | **453 MB** | identical to before |
| After (yields rows) | 233 MB | **233 MB** | identical to before |

- Run time is the same (about 56 s either way).
- Randomized check: 200,000 key histories of up to 6 lines gave the same winner as your old `_resolve` every time. In a stress run of up to 12 lines per key, 0.42% differed, because the cap of 6 prunes entries beyond that.
- **453 MB is only about 59 MB under the limit.** Treat the list version as the fallback. To yield rows, replace `rows.append(` with `yield (` in `finalize` and drop `rows = []` / `return rows`. Test it on the sample run first: if the harness accepts a generator, use it. I could not check that from here `[untested]`.
- Real data can differ (longer units, more lines per key). Test locally at 1M lines before submitting.

---

## 2. Merged chart numbers never applied

**Your code**
```python
 25  APPLY_MERGES = False         # remap retired MR numbers (from MRG) to the surviving PID number
...
356          if "ORU" not in g(msh, 8).upper():
357              return None
...
364          mrg = parsed.get("MRG")
365          if mrg and pid and not trunc:
366              for old, a, _t in _cx(g(mrg, 1)):
367                  if re.fullmatch(r"\d{8}", old) and a in ("", "HOSP") and old != pid:
368                      self.merge[old] = pid
```

**Gold code** `[not available]`

**Example input**
`ADT^A40` with PID-3 `12345678^^^HOSP^MR` and MRG-1 `87654321^^^HOSP^MR`, then a later ORU result under `87654321`.

**Your behavior**
The ADT message returns `None` at L357 before L364 runs, so `self.merge` is always empty. Even with `APPLY_MERGES = True`, nothing would be remapped. `patient_id` keeps the retired number.

**Gold behavior** `[not available]`

**Why it matters**
Merged chart numbers are 7.0% of the stream and change every result that follows.

**Before** is the code above (handler.py L25, L356–357, L364–368).

**After**
```python
APPLY_MERGES = True

# inside _parse(), replacing the ORU gate:
if "ADT" in g(msh, 8).upper():                 # merge message: remember retired -> kept, emit no result
    kept, mrg = pick_pid(parsed.get("PID")), parsed.get("MRG")
    if kept and mrg and not trunc:
        for old, a, _t in _cx(g(mrg, 1)):
            if re.fullmatch(r"\d{8}", old) and a in ("", "HOSP") and old != kept:
                self.merge[old] = kept
    return None
if "ORU" not in g(msh, 8).upper():
    return None
```

**How it works**
The merge message is read before the ORU filter throws it away, so the handler learns which retired number maps to which surviving number. `finalize` already follows chains through `_final_pid`.

**Proof** `[estimate]`: on a hand-built ADT + ORU pair, `patient_id` was `87654321` before and `12345678` after. This version applies the remap to all results of that retired number, not only the ones after the merge. The README says a merge changes every result that follows, so check the sample for results before the merge `[untested]`.

---

## 3. Test mapping and OBX choice

**Your code**
```python
378          for f in obxs:
379              comps = g(f, 3).split("^")
380              c0 = comps[0].strip().upper()
381              c3 = comps[3].strip().upper() if len(comps) > 3 else ""
382              t = TEST_CODES.get(c0) or TEST_CODES.get(c3)
383              if t:
384                  obx, test, code = f, t, c0
385                  break
386          if obx is None:
387              obx = obxs[0]
388              code = g(obx, 3).split("^")[0].strip().upper()
389              if not EMIT_UNMAPPED_TESTS:
390                  return None
391              if not code:
392                  return None
```

**Gold code**
```python
# gold_submit.py L280–287 _test: codes at positions 0 and 3, with the coding system checked
if code in _TEST_CODES and system in ('', 'LN', 'LOINC', 'L', 'LOCAL'): return _TEST_CODES[code]
```
`_TEST_NAMES` (L8) is defined; its use `[not available]`.

**Example input**
`OBX|1|NM|Na+||140|mmol/L|||||F`, and a panel with a comment OBX first: `OBX|1|ST|2345-7^Glucose^LN||see note` then `OBX|2|NM|2345-7^Glucose^LN||101|mg/dL|||||F`.

**Your behavior**
`Na+` is not in `TEST_CODES`, so the row is emitted with `test=None` under key `(acc, None)`. Your own comment at L375 says a wrong row costs points `[inferred]`. The first mapped OBX wins whatever its value type, so a comment OBX can be chosen over the numeric one.

**Gold behavior**
It checks the coding system. Name mapping and OBX selection `[not available]`.

**Why it matters**
Test codes in 5 ways are 15% of the stream, tests named but not coded 12%, LOINC alternate 9%, more than 1 OBX 12%.

**Before** is the code above (handler.py L378–392).

**After**
```python
TEST_NAMES = {"glucose": "glucose", "sodium": "sodium", "na+": "sodium", "na": "sodium",
              "potassium": "potassium", "k+": "potassium", "creatinine": "creatinine",
              "hemoglobin": "hemoglobin", "wbc": "wbc", "white blood cell count": "wbc"}

def test_from_obx3(f):
    comps = g(f, 3).split("^")
    for i in (0, 3, 1):                         # code, alternate code, then the name
        c = comps[i].strip() if len(comps) > i else ""
        if not c:
            continue
        t = TEST_CODES.get(c.upper()) or TEST_NAMES.get(c.lower().split(",")[0].strip())
        if t:
            return t, c.upper()
    return None, ""

# inside _parse(), replacing the OBX loop:
mapped = [(f, *test_from_obx3(f)) for f in obxs]
mapped = [m for m in mapped if m[1]]
for f, t, c in mapped:                          # first choice: the mapped OBX whose value is a number
    if parse_value(g(f, 5), g(f, 8)) is not None:
        obx, test, code = f, t, c
        break
if obx is None and mapped:
    obx, test, code = mapped[0]

EMIT_UNMAPPED_TESTS = False                     # never emit a row with test = None
```

**How it works**
A name like `Na+` or `Glucose, serum` is mapped to the same six tests. When a result has several OBX segments, the one whose value is a number is chosen before a comment. Rows with no recognized test are no longer emitted.

**Proof** `[estimate]`: `Na+` gave `None` before and `sodium` after; `Glucose, serum` gave `None` before and `glucose` after; the comment-then-numeric panel gave `None` before and `101.00` after. The name list is my guess from the README; extend it from the sample `[untested]` for names I did not include.

---

## 4. Collection time sources

**Your code**
```python
406              "obs": fmt_ts(parse_ts(g(obr, 7).split("^")[0], zone)),
```

**Gold code**
`_time` (gold_submit.py L195–240) parses a time string and splits on `^`. Which fields feed it `[not available]`.

**Example input**
- OBR-7 empty and `SPM|1|...|20260101080000^20260101081500` (SPM-17 range).
- OBR-7 empty and the time stamped on OBX-14.
- OBR-7 filled and OBX-14 hours later (the analyzer's run time).

**Your behavior**
SPM is never read and the OBX time is never read, so `observed_at` is `None` for the first two cases. The third is correct because OBR-7 wins.

**Gold behavior** `[not available]`

**Why it matters**
SPM-17 is 12% of the stream, time moved to the OBX 8%, and run time beside the draw 25%.

**Before** is the code above (handler.py L406).

**After**
```python
# inside _parse(), replacing the OBR-7 line:
raw_t = g(obr, 7).split("^")[0]
if not raw_t.strip("0 "):                                   # empty or all zeros
    raw_t = g(parsed.get("SPM"), 17).split("^")[0]          # collection start from SPM-17
if not raw_t.strip("0 "):
    raw_t = g(obx, 14)                                       # last resort: time on the OBX
obs = parse_ts(raw_t, zone) if raw_t.strip("0 ") else None
```

**How it works**
The collection time comes from OBR-7 first, then the start of the SPM-17 range, then the OBX time as a last resort. The analyzer's run time is never used when OBR-7 is present.

**Proof** `[estimate]`: SPM-17 gave `None` before and `2026-01-01T13:00:00Z` after; OBX-14 gave `None` before and `2026-01-01T13:00:00Z` after; OBR-7 present with a later OBX-14 stayed `2026-01-01T13:00:00Z` in both.

---

## 5. Flags written in the value

**Your code**
```python
246      s = v.replace(" ", "")
247      if re.fullmatch(r"[-+]?\d{1,3}(?:,\d{3})+(?:\.\d+)?", s):
248          s = s.replace(",", "")
249      elif re.fullmatch(r"[-+]?\d+,\d+", s):
250          s = s.replace(",", ".")
251      if not NUM_RE.fullmatch(s):
252          return None
```

**Gold code**
```python
# gold_submit.py L257: same style of full match, after decoding
if len(text) > 80 or not _NUMBER.fullmatch(text): return _NONE
```

**Example input**
`OBX|1|ST|2345-7^Glucose^LN||95 H|mg/dL|70-99|H|||F`

**Your behavior**
`95H` fails the match, so `value` is `None`.

**Gold behavior**
The same in the visible helper. A caller might strip the flag first `[not available]`.

**Why it matters**
Flags in the value are 20% of the stream, and the README says the number in front of the flag is the result.

**Before** is the code above (handler.py L246–252).

**After**
```python
FLAG_TAIL = re.compile(r"([-+]?\d[\d,]*\.?\d*)\s*(?:HH|LL|H|L|A|N|\*)", re.I)
_parse_value_orig = parse_value

def parse_value(v, flag):                      # strip an abnormal flag typed after the number ("95 H")
    m = FLAG_TAIL.fullmatch(hl7u(v).strip())
    return _parse_value_orig(m.group(1) if m else v, flag)
```

**How it works**
If the text is a number followed by a flag letter, the flag is removed and the number goes through your existing rules. Everything else is untouched.

**Proof** `[estimate]`: `95 H` gave `None` before and `95.00` after.

---

## 6. DST and patient-id ambiguity

**Your code**
```python
170  def _localize(dt, zone):
171      if zone is None:  # sender unknown: an offset-less time cannot be resolved -> null
172          return None
173      name = "America/New_York" if zone == "E" else "America/Chicago"
174      if ZoneInfo is not None:
175          try:
176              tz = _TZ.get(name)
177              if tz is None:
178                  tz = _TZ[name] = ZoneInfo(name)
179              return dt.replace(tzinfo=tz).astimezone(timezone.utc)
180          except Exception:
181              pass
182      off = (-5 if zone == "E" else -6) + (1 if _is_dst(dt) else 0)
183      return (dt - timedelta(hours=off)).replace(tzinfo=timezone.utc)
...
304  def pick_pid(pid_seg):
305      if not pid_seg:
306          return None
307      items = _cx(g(pid_seg, 3)) + _cx(g(pid_seg, 2))
308      ok = [(p, a, t) for p, a, t in items if re.fullmatch(r"\d{8}", p)]
309      for cond in (lambda a, t: a == "HOSP" and t == "MR",
310                   lambda a, t: a == "HOSP" and t == "",
311                   lambda a, t: a == "" and t in ("", "MR")):
312          for p, a, t in ok:
313              if cond(a, t):
314                  return p
315      return None
```

**Gold code**
```python
# gold_submit.py L231–236: repeated or missing local hour -> _NONE
if a.utcoffset() != b.utcoffset(): return _NONE
# gold_submit.py L170–177 _patient: more than one distinct HOSP MR -> _NO_PATIENT
```

**Example input**
- A no-offset `20261101013000` from an Eastern sender (01:30 happens twice that night).
- PID-3 with two different `HOSP^MR` numbers.

**Your behavior**
The first gets an instant from the first occurrence. The second returns the first number found.

**Gold behavior**
Both become null.

**Why it matters**
Times with no offset are 12% of the stream, MRN forms 12%, two issuers 11%. That null is the right answer is my reading of gold's choice `[inferred]`.

**Before** is the code above (handler.py L170–183, L304–315).

**After**
```python
def _localize(dt, zone):                        # repeated / missing local hours have no single instant -> null
    if zone is None:
        return None
    tz = ZoneInfo("America/New_York" if zone == "E" else "America/Chicago")
    a, b = dt.replace(tzinfo=tz, fold=0), dt.replace(tzinfo=tz, fold=1)
    return None if a.utcoffset() != b.utcoffset() else a.astimezone(timezone.utc)

def pick_pid(pid_seg):                          # more than one distinct hospital chart number -> null
    if not pid_seg:
        return None
    items = _cx(g(pid_seg, 3)) + _cx(g(pid_seg, 2))
    ok = [(p, a, t) for p, a, t in items if re.fullmatch(r"\d{8}", p)]
    for cond in (lambda a, t: a == "HOSP" and t == "MR",
                 lambda a, t: a == "HOSP" and t == "",
                 lambda a, t: a == "" and t in ("", "MR")):
        found = {p for p, a, t in ok if cond(a, t)}
        if len(found) == 1:
            return next(iter(found))
        if len(found) > 1:
            return None
    return None
```

**How it works**
A local time with no offset is checked at both possible clock folds. If they disagree (a repeated or skipped hour), no single instant exists, so the time is null. The patient picker returns null when two different hospital numbers are present, instead of guessing the first.

**Proof** `[estimate]`: the repeated 01:30 gave `2026-11-01T05:30:00Z` before and `None` after; two `HOSP^MR` numbers gave `11111111` before and `None` after. Whether null is the expected answer in the real grader is `[inferred]`.

---

### Proof for sections 2 to 6 together `[estimate]`

- Ten hand-built checks (merge, names, comment OBX, SPM-17, OBX-14, OBR-7 priority, flag, repeated hour, two chart numbers) all pass with the patched handler. Nine of them returned a different result before.
- On a 20,000-key synthetic stream the fully patched handler returned rows identical to your original, so the patches did not disturb the ordinary cases.

## Not compared (gold incomplete)

- Continuation lines after a typed line feed (`split_segments`, handler.py L57–61).
- Duplicate and revision resolution in gold.
- Where gold gets the sender's time zone (`sender_zone`, handler.py L219–227, is a heuristic).

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.best = {}      # (acc, test_code) -> packed bytes: winner + last-valued slot
        self.merges = {}    # retired chart number -> kept chart number

    def process(self, raw):
        parsed = parse_message(raw)                  # json / MLLP / double-escape; continuation lines joined
        if is_merge(parsed):
            self.merges.update(read_merge(parsed)); return []
        rec = pack_result(parsed)                    # ints: value cents, unit code, times, status rank, pid
        if rec:
            self.best[rec.key] = resolve(self.best.get(rec.key), rec)   # reconcile on arrival
        return []                                    # never emit here, never keep every line

    def finalize(self):
        return (unpack(k, v, self.merges) for k, v in self.best.items())   # one row per key
```

## Checklist to avoid a score of 0

1. **Judge memory by what you store, not by what you do.** "19/512 MB" on 300 lines is mostly Python. Measure at 20k, 200k and 1M synthetic lines and look at the slope.
2. **Keep per-key state, never per-line state.** Reconcile as each line arrives.
3. **Use small types for stored state:** ints and packed bytes instead of dicts and strings.
4. **Check the output cost.** 750k row dicts are about 200 MB by themselves, so free state as you build rows, or yield them.
5. **A stop before `finalize` returns nothing.** With `process` returning `[]`, nothing is scored if the run dies earlier, so the state must be bounded.
