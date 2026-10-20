# Worked example: Week 4 (score 0, out of memory)

This is section 1 and the checklist of the real Week 4 analysis. It shows the required shape: your code verbatim (Before),
the proposed code (After), a plain-language explanation, and proof from a local test on synthetic data.

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

---

## Checklist to avoid a score of 0

1. **Judge memory by what you store, not by what you do.** "19/512 MB" on 300 lines is mostly Python. Measure at 20k, 200k and 1M synthetic lines and look at the slope.
2. **Keep per-key state, never per-line state.** Reconcile as each line arrives.
3. **Use small types for stored state:** ints and packed bytes instead of dicts and strings.
4. **Check the output cost.** 750k row dicts are about 200 MB by themselves, so free state as you build rows, or yield them.
5. **A stop before `finalize` returns nothing.** With `process` returning `[]`, nothing is scored if the run dies earlier, so the state must be bounded.
