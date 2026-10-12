# Week 4 — The Interface: Code Review, Memory Failure, and Proposed Fix

## 1. Results and the real reason for the zero score

| Metric | Result |
|---|---:|
| Submitted score | 0.0000 |
| Rank | #6 of 6 |
| Rows recovered by submitted run | 0 of 749,978 |
| Memory limit | 512 MB |
| Projected memory usage | About 1,238 MB |
| Work per record | 1.77× median |
| Offline score | 0.7883 — would have ranked second |
| Run | Stopped at record 1,000,000 |

**The immediate cause of the zero score was memory exhaustion.** Your handler retained candidate records and message fingerprints throughout the input stream. The process was stopped before `finalize()` returned the output rows, so the evaluator had no completed result to score.

This does not prove that every part of your parser was correct. It does explain why a potentially strong parsing solution received a zero in the submitted run.

### Why the sample test was misleading

Your sample used only 300 lines and reported a peak of 19 MB. That measurement mainly reflected Python's baseline memory usage and was too small to expose the growth of your data structures. The full-stream projection was approximately 1,238 MB—more than twice the 512 MB limit.

**Lesson:** Test correctness and resource usage at realistic input sizes. A program that works on a few hundred rows can fail on a million rows even if its per-record processing cost is competitive.

## 2. Problem #1 — Retaining every candidate until `finalize()`

### Before: your current code

In `Handler.__init__()`:

```python
class Handler:
    def __init__(self):
        self.groups = {}
        self.seen = set()
        self.merge = {}
        self.n = 0
```

In `process()`:

```python
def process(self, raw):
    try:
        e = self._parse(raw)
        if e is not None:
            self.groups.setdefault(e.get("key"), []).append(e)
    except Exception:
        pass
    return []
```

And in `finalize()`:

```python
def finalize(self):
    rows = []
    for entries in self.groups.values():
        w = self._resolve(entries)
        if w is None:
            continue
        rows.append({
            "accession": w["acc"],
            "test": w["test"],
            "patient_id": self._final_pid(w["pid"]),
            "value": w["val"],
            "unit": w["unit"],
            "observed_at": w["obs"],
            "status": w["st"] if w["st"] in OUT_STATUS else None,
        })
    return rows
```

### Why this grows

Suppose the stream contains preliminary glucose 90, final glucose 95, and final sodium 140. Your `groups` structure retains all three candidates, including both glucose versions, until the end. Each candidate is a dictionary stored inside a list inside a dictionary. The history is useful for correctness, but costly at scale.

### After: a compact intermediate representation

The current candidate contains:

```python
return {
    "key": (acc, test),
    "acc": acc,
    "test": test,
    "pid": pid,
    "val": val,
    "unit": norm_unit(g(obx, 6)),
    "obs": fmt_ts(parse_ts(g(obr, 7).split("^")[0], zone)),
    "st": st,
    "ts": parse_ts(g(msh, 6), zone),
    "trunc": trunc,
    "seq": self.n,
}
```

A tuple representation could reduce per-candidate overhead:

```python
# 0 accession, 1 test, 2 patient_id, 3 value,
# 4 unit, 5 observed_at, 6 status, 7 message_time,
# 8 truncated, 9 sequence
candidate = (
    acc, test, pid, val,
    norm_unit(g(obx, 6)),
    fmt_ts(parse_ts(g(obr, 7).split("^")[0], zone)),
    st,
    parse_ts(g(msh, 6), zone),
    trunc,
    self.n,
)
```

This is an intermediate optimization, not a complete fix. The tuple still needs to be stored for every candidate, and `self.seen` still grows with unique message fingerprints. Changing dictionaries to tuples also requires adapting `_resolve()` and `finalize()`.

## 3. Problem #2 — Reduce retained state with an incremental reducer

### Current approach

```text
Read message -> parse candidate -> append to groups[key]
             -> retain all candidates -> resolve at finalize()
```

### Proposed target

```text
Read message -> parse candidate -> identify result key
             -> update compact state -> discard unneeded candidate details
             -> finalize remaining state and emit rows
```

The goal is to retain the smallest state that still preserves the challenge's reconciliation rules.

### Proposed code pattern (design sketch, not drop-in code)

```python
class Handler:
    def __init__(self):
        self.best_by_key = {}
        self.seen = set()  # keep only if required by deduplication semantics
        self.merge = {}
        self.n = 0

    def process(self, raw: str) -> list[dict]:
        candidate = self._parse(raw)
        if candidate is None:
            return []

        key = candidate["key"]
        current = self.best_by_key.get(key)
        updated = self._update_state(current, candidate)

        if updated is not None:
            self.best_by_key[key] = updated

        return []

    def finalize(self) -> list[dict]:
        return [
            self._to_output(candidate)
            for candidate in self.best_by_key.values()
        ]
```

`_update_state()` and `_to_output()` are placeholders; this sketch is not executable as written. They must be implemented to preserve the actual rules.

### Why not simply keep the latest message?

Your current `_resolve()` sorts by timestamp and sequence, handles `U` statuses specially, considers truncation, ranks corrected/final/withdrawn/preliminary statuses, and uses timestamps and sequence numbers to break ties. A later-arriving message may have an earlier timestamp, and withdrawals or corrections can change the winner.

Therefore, replacing `groups[key].append(candidate)` with `best_by_key[key] = candidate` may save memory but produce incorrect rows.

**The right optimization is an incremental reducer proven equivalent to `_resolve()`, not simply overwriting the previous candidate.** Test it against the current resolver over many small histories with different statuses, timestamps, sequence orders, and truncation states.

## 4. Problem #3 — The fingerprint set also grows

### Before: current deduplication

```python
digest = hashlib.md5(
    s.encode("utf-8", "ignore")
).digest()

if digest in self.seen:
    return None

self.seen.add(digest)
```

The digest is 16 bytes, but the Python set also needs space for its table and entries. Its memory grows independently of `groups`. Removing old candidates does not reduce this set.

### Proposed change

Before redesigning deduplication, establish whether duplicates can occur far apart in the stream and whether identical messages can represent legitimate revisions. If duplicates are guaranteed to be adjacent, a last-message fingerprint might suffice—but only if that guarantee is real. If duplicates can recur anywhere, a global set may be necessary unless an equivalent strategy exists.

**Do not remove deduplication solely to lower memory.** First reduce candidate-history memory, then measure the fingerprint set's contribution, and only then redesign it if semantics allow.

## 5. Problem #4 — A message can contain multiple OBX results

This is a separate correctness issue, not the documented cause of the zero score.

### Before: current code

```python
obx, test, code = None, None, ""

for f in obxs:
    comps = g(f, 3).split("^")
    c0 = comps[0].strip().upper()
    c3 = comps[3].strip().upper() if len(comps) > 3 else ""
    t = TEST_CODES.get(c0) or TEST_CODES.get(c3)

    if t:
        obx, test, code = f, t, c0
        break
```

The `break` exits after the first recognized test.

### Example

```text
OBX|1|NM|2345-7^Glucose^LN||95|mg/dL|||N|||F
OBX|2|NM|2951-2^Sodium^LN||140|mmol/L|||N|||F
OBX|3|NM|2823-3^Potassium^LN||4.1|mmol/L|||N|||F
```

Your current loop selects glucose and stops; sodium and potassium are never made into candidates.

### After: proposed structure

```python
candidates = []

for obx in obxs:
    candidate = self._parse_obx(
        obx=obx,
        obr=obr,
        msh=msh,
        pid=pid,
        accession=acc,
        truncated=trunc,
    )
    if candidate is not None:
        candidates.append(candidate)

return candidates
```

This is a structural example, not a drop-in patch: `_parse()` currently returns one candidate or `None`, so both it and its caller must change. Each eligible OBX needs its own key and reconciliation. Exclude comments and non-result OBXs according to the challenge rules. Test that one message with three eligible results produces three rows.

## 6. Other correctness risks to address after memory

### Test, value, and unit normalization

Your `TEST_CODES`, `parse_value()`, and `norm_unit()` provide a foundation, but the stream includes alternate LOINC/local codes, named tests, typed values, flags, and unit variants. For example, `parse_value()` returns `None` for values starting with `<` or `>`. Confirm the expected representation before discarding comparators or bounds.

### Patient identifiers and merges

`APPLY_MERGES = False` disables the merge-resolution path. Test multiple identifier forms, assigning authorities, and chart merges after stabilizing memory.

### Observation timestamps

The current output relies on OBR-7, but relevant time can also appear in SPM-17 and OBX fields. Add timestamp-source precedence tests and verify timezone handling.

### Status changes and withdrawals

Your `_resolve()` contains special logic for `U` and ranks statuses. Any incremental reducer must preserve these semantics. Test preliminary-to-final transitions, corrections, withdrawals, duplicates, and out-of-order messages.

### Hidden exceptions

Your `process()` catches all exceptions and suppresses them:

```python
try:
    e = self._parse(raw)
    if e is not None:
        self.groups.setdefault(e.get("key"), []).append(e)
except Exception:
    pass
```

This can hide parser defects. During local development, count exceptions and record safe diagnostic categories; avoid logging patient-identifying information.

## 7. Practical validation plan

### Step 1 — Establish a correctness baseline

Save expected output for: one-result messages, multi-OBX messages, duplicate messages, preliminary followed by final, corrected and withdrawn results, out-of-order timestamps, truncated messages, and chart merges.

### Step 2 — Measure memory at realistic sizes

| Input size | What to check |
|---|---|
| 300 records | Small-input baseline |
| 10,000 records | Early growth pattern |
| 100,000 records | Large-scale growth |
| 1,000,000 records | Whether the design stays below 512 MB |

Identify which structures grow with input size; do not merely check whether one run finishes.

### Step 3 — Test compact candidate storage

Replace candidate dictionaries with tuples or another compact representation, adapt `_resolve()` and `finalize()`, and compare output to the baseline. Measure memory again; do not assume this alone is sufficient.

### Step 4 — Prove the incremental reducer equivalent

Generate many small candidate histories with different statuses, timestamps, sequence orders, and truncation states. Compare the new reducer's selected result with the current `_resolve()`. If they differ, the reducer is not yet equivalent.

### Step 5 — Run the complete stream

Verify that the process completes within the memory limit, returns all expected rows, and retains high row-level correctness.

## 8. Recommended priority order

1. **Fix the memory failure** that caused the zero score.
2. Measure memory after each change.
3. Preserve reconciliation behavior while reducing retained state.
4. Fix multi-OBX handling so one message can produce multiple result rows.
5. Expand test-code, value, unit, patient-ID, and timestamp coverage.
6. Validate revisions, withdrawals, duplicates, and out-of-order messages.
7. Improve diagnostics so parsing failures are visible during development.

## Notes on `gold_submit.py`

The checked-in `gold_submit.py` contains parsing helpers for message extraction, HL7 escapes, patient identifiers, timestamps, values, units, and test codes. The file ends after `_test()`; it does not contain a visible `Handler`, `process()`, `finalize()`, or complete output-resolution pipeline. This review compares the submitted handler with the available reference helpers and does not invent missing gold-pipeline behavior.

## Final takeaway

Your score of zero was primarily an execution failure: the handler accumulated too much state and did not return rows before hitting the memory limit. Your offline score of 0.7883 suggests the underlying parsing approach has potential.

Do not rewrite everything at once. Start with memory measurements, compact the retained state, and then implement a carefully tested incremental reducer. A fast parser is not enough if it cannot finish the stream, and a memory-efficient parser is not enough if it changes which result wins.

The target is a handler that is **correct, bounded in memory, and able to complete the entire million-record workload**.
