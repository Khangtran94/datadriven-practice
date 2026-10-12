# Week 4 – The Interface: handler.py vs gold_submit.py

**Your score:** 0.0000 (#6 of 6)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

**Why the score is 0**  
Your run scored 0 because it ran out of memory. The handler kept the candidate for every key **plus** a fingerprint of every line, and only builds rows at the end in `finalize()`. Over 1 000 000 lines that grows to ~1.2 GB against the 512 MB limit. The run was stopped after reading every record but before `finalize()` returned any rows, so nothing was scored.  

The sample could not show this (“Peak memory 19/512 MB” measured only 300 lines). On the full stream the projection is ~1 238/512 MB.  

Work per record was actually strong (1.77× median vs the winner’s 1.71×). Offline on the same stream your rows would have scored **0.7883** (second place). The logic is solid; the architecture simply retained too much state.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Memory / state retention | OOM at ~1.2 GB. Kept every candidate + every line fingerprint. Run never reached `finalize()`. |
| 2 | Keep only the current winner | Storing full history of candidates for every key is the dominant memory cost. |
| 3 | Fingerprint / seen set | `self.seen` grows with every unique message; unnecessary once you keep only the best row. |
| 4 | Dicts vs compact tuples | Dicts per candidate multiply memory; small tuples + integer codes cut it dramatically. |
| 5 | Status / revision ranking | Correct final-vs-preliminary / W / U handling is already present; just needs to run under the limit. |
| 6 | Test / unit / time recovery | Many of the 30+ stream conditions are partially handled; memory was the blocker. |

---

## 1. Memory / state retention (the score-zero cause)

**Your code**
```python
# __init__
self.groups = {}          # key → list of every candidate
self.seen = set()         # md5 of every unique message body
self.merge = {}
self.n = 0

# process
e = self._parse(raw)
if e is not None:
    self.groups.setdefault(e.get("key"), []).append(e)
return []

# finalize – never reached on the full stream
for entries in self.groups.values():
    w = self._resolve(entries)
    ...
```

**Gold pattern (typical top solution)**
```python
# keep only the single best row (or a tiny tuple) per key
self.held = {}            # key → best candidate (tuple or compact object)
# no permanent “seen” set of every line
# process updates the single winner; finalize just emits the dict values
```

**Example input**  
1 000 000 lines, many keys that receive 2–5 revisions or duplicates.

**Your behavior**  
Every candidate is appended. Fingerprints accumulate. Memory climbs past 512 MB → process killed → 0 rows scored.

**Gold behavior**  
Only the current winner is retained. Memory stays well under the limit; `finalize` returns the full table.

**Why it matters**  
This is the sole reason the official score is 0. Offline the same logic scores 0.7883.

**What to change**  
- Keep **only the current winner** for each `(accession, test)` key.  
- Drop (or bound) the line-fingerprint set.  
- Prefer small tuples / integer codes over full dicts.

---

## 2. Keep only the current winner

**Your code**
```python
# process always appends
self.groups.setdefault(e.get("key"), []).append(e)

# resolve only at the very end
def _resolve(entries):
    entries = sorted(entries, key=lambda e: (e["ts"] or MIN_TS, e["seq"]))
    ...
    return max(cands, key=lambda c: (not c["trunc"], RANK.get(c["st"], 0), ...))
```

**Gold / recommended**
```python
def process(...):
    cand = parse(...)
    if cand is None:
        return []
    key = cand.key
    prev = self.held.get(key)
    if prev is None or better(cand, prev):
        self.held[key] = cand          # replace, never accumulate
    return []

def finalize(self):
    return [to_row(c) for c in self.held.values()]
```

**Example input**  
Same accession + test receives a preliminary, then a final, then a duplicate final.

**Your behavior**  
Three full dicts live in the list until the end.

**Gold behavior**  
Only the best (final) survives in memory.

**Why it matters**  
The list-of-candidates design is the dominant memory multiplier on a 1 M-line stream.

**What to change**  
Update-in-place. Never keep history once a better candidate has been seen.

---

## 3. Fingerprint / seen set

**Your code**
```python
digest = hashlib.md5(s.encode("utf-8", "ignore")).digest()
if digest in self.seen:
    return None
self.seen.add(digest)
```

**Gold / recommended**  
Most top solutions either skip permanent fingerprints or use a very short-lived / bounded structure. Deduplication is usually achieved by the “keep-best” logic itself (identical content produces an identical or worse candidate).

**Why it matters**  
On a stream with many exact replays the set alone can consume hundreds of megabytes.

**What to change**  
Remove `self.seen` (or make it a small LRU / bloom filter) once you keep only the winner.

---

## 4. Compact representation

**Your code**  
Each candidate is a full Python dict with string keys and string values.

**Gold pattern**  
Integer codes for test / unit / status, microsecond timestamps as int, patient_id as int or None, etc. A 7–8 element tuple is dramatically cheaper than a dict.

**Why it matters**  
Dicts have high per-object overhead. On hundreds of thousands of keys the difference is hundreds of MB.

**What to change**  
Store the minimal fields needed for ranking and emission as a tuple (or a tiny `__slots__` object).

---

## 5. Status / revision ranking (already strong)

**Your code**
```python
RANK = {"corrected": 4, "final": 3, "W": 2, "preliminary": 1}
# _resolve prefers non-truncated, higher RANK, later timestamp, later seq
# special handling for status "U"
```

This logic is already close to what a top solution needs. Once memory is fixed it will contribute to the 0.7883 offline score.

---

## 6. Other recovery areas (secondary once memory is fixed)

The README lists 30+ conditions (extra segments, non-numeric values, units as typed, MRN forms, merges, SPM-17 time, LOINC alternate, flags inside the value, MLLP framing, doubled backslashes, etc.).  

Your parser already covers a substantial subset (JSON envelope recovery, HL7 escapes, unit normalisation, PID selection, status mapping, time-zone inference). The remaining gaps are real but secondary to the OOM.

After the memory rewrite, re-run offline and measure which of the high-frequency conditions (key-order changes, extra segments, non-numeric values, units, test-code variants) still cost cells.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}          # key → single best candidate (tuple / compact)
        # optional: self.merge = {} for MRG → PID remapping
        # NO permanent set of every line fingerprint

    def process(self, raw: str) -> list[dict]:
        cand = self._parse(raw)          # returns None or a compact candidate
        if cand is None:
            return []
        key = cand.key
        prev = self.held.get(key)
        if prev is None or self._better(cand, prev):
            self.held[key] = cand
        return []                        # never emit here

    def finalize(self) -> list[dict]:
        # optional: apply merges, resolve any remaining status edge-cases
        return [self._to_row(c) for c in self.held.values()]
```

Keep only the current winner, store small tuples, drop the global fingerprint set, and the same logic that scored 0.7883 offline will finish under the 512 MB limit and produce a real ranking.
