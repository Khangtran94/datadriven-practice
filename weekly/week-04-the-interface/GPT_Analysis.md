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

---

# Rerun update — Week 4 — The Interface: complete before/after code

The submitted run scored zero because it crashed at record 1,000,000 before finalization, with projected memory around 1,238 MB against a 512 MB limit. Main memory risks are candidate-history lists and the global fingerprint set. Correctness also requires processing every eligible OBX result in a message.

## Code before — exact current handler.py

The following is the complete handler snapshot fetched for this rerun, included verbatim as the before reference.

```python
import json
import re
import hashlib
from datetime import datetime, timezone, timedelta, date
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP

try:
    from zoneinfo import ZoneInfo
except Exception:  # pragma: no cover
    ZoneInfo = None

# ----------------------------------------------------------------- constants
TEST_CODES = {
    "2345-7": "glucose", "2951-2": "sodium", "2823-3": "potassium",
    "2160-0": "creatinine", "718-7": "hemoglobin", "6690-2": "wbc",
    "GLU": "glucose", "NA": "sodium", "K": "potassium",
    "CREAT": "creatinine", "HGB": "hemoglobin", "WBC": "wbc",
}
STATUS_MAP = {"F": "final", "P": "preliminary", "C": "corrected", "W": "W", "U": "U"}
RANK = {"corrected": 4, "final": 3, "W": 2, "preliminary": 1}
OUT_STATUS = {"final", "preliminary", "corrected"}
MIN_TS = datetime.min.replace(tzinfo=timezone.utc)

EMIT_UNMAPPED_TESTS = True   # rows whose OBX-3 is not one of the 6 tests -> test = null
APPLY_MERGES = False         # remap retired MR numbers (from MRG) to the surviving PID number

# ------------------------------------------------------------ escape helpers
_UNESC = {"r": "\r", "n": "\n", "t": "\t"}
_HL7ESC = {"F": "|", "S": "^", "T": "&", "R": "~", "E": "\\"}


def unlayer(s):
    """Undo one layer of JSON-style backslash escaping."""
    return re.sub(r'\\(["\\/rnt])', lambda m: _UNESC.get(m.group(1), m.group(1)), s)


def hl7u(s):
    """HL7 escape sequences (\\F\\ \\S\\ \\T\\ \\R\\ \\E\\)."""
    if "\\" not in s:
        return s
    return re.sub(r"\\([FSTRE])\\", lambda m: _HL7ESC[m.group(1)], s)


def fix_layers(s):
    for _ in range(3):
        if re.search(r"[\r\n]", s):
            break
        if "\\r" in s or "\\n" in s:
            s = unlayer(s)
        else:
            break
    if "^~\\\\&" in s:  # encoding characters still doubled -> one more layer
        s = unlayer(s)
    return s


def split_segments(s):
    parts = [p for p in re.split(r"\r\n|\r|\n", s) if p.strip()]
    if len(parts) < 3:
        parts = [p for p in re.split(r"\s+(?=[A-Z][A-Z0-9]{2}\|)", s.strip()) if p.strip()]
    return parts


def g(fields, i):
    return fields[i].strip() if fields and i < len(fields) else ""


# ------------------------------------------------------------- JSON envelope
MSG_RE = re.compile(r'"message"\s*:\s*"((?:[^"\\]|\\.)*)("?)')
CONN_RE = re.compile(r'"connection"\s*:\s*"([^"]*)"')


def _find_msg(obj, depth=0):
    if depth > 5:
        return None
    if isinstance(obj, str):
        s = obj.strip()
        if s and s[0] in ('{', '[', '"'):
            try:
                r = _find_msg(json.loads(s, strict=False), depth + 1)
                if r:
                    return r
            except ValueError:
                pass
        return obj if "MSH|" in obj else None
    if isinstance(obj, dict):
        for k in ("message", "msg", "hl7", "body", "payload", "data"):
            if k in obj:
                r = _find_msg(obj[k], depth + 1)
                if r:
                    return r
        for v in obj.values():
            r = _find_msg(v, depth + 1)
            if r:
                return r
        return None
    if isinstance(obj, list):
        for v in obj:
            r = _find_msg(v, depth + 1)
            if r:
                return r
    return None


def extract(raw):
    """-> (message_text, truncated, connection) or None."""
    if not isinstance(raw, str):
        return None
    text = raw.lstrip("\ufeff").strip()
    if not text:
        return None
    obj = None
    try:
        obj = json.loads(text, strict=False)
        for _ in range(3):
            if isinstance(obj, str):
                try:
                    obj = json.loads(obj, strict=False)
                except ValueError:
                    break
            else:
                break
    except ValueError:
        obj = None
    if isinstance(obj, dict):
        msg = _find_msg(obj)
        return (msg, False, str(obj.get("connection") or "")) if msg else None
    if isinstance(obj, str):
        return (obj, False, "") if "MSH|" in obj else None
    if obj is not None:
        return None
    # broken / truncated JSON -> recover the message string by regex
    t = text
    m = None
    for _ in range(3):
        m = MSG_RE.search(t)
        if m or not t.startswith('"'):
            break
        t = unlayer(t[1:])
    cm = CONN_RE.search(t)
    conn = cm.group(1) if cm else ""
    if m:
        body, closed = m.group(1), m.group(2)
        try:
            msg = json.loads('"' + body + '"', strict=False)
        except ValueError:
            msg = unlayer(body)
        return msg, closed == "", conn
    i = t.find("MSH|")
    if i < 0:
        return None
    return unlayer(t[i:]), True, conn


# ------------------------------------------------------------------- time
DTM_RE = re.compile(
    r"(\d{4})(\d{2})(\d{2})(\d{2})(\d{2})(\d{2})?(?:\.\d+)?\s*(Z|[+-]\d{2}(?::?\d{2})?)?")
_TZ = {}


def _is_dst(dt):
    y = dt.year
    d = date(y, 3, 1)
    start = datetime(y, 3, 1 + (6 - d.weekday()) % 7 + 7, 2)
    d = date(y, 11, 1)
    end = datetime(y, 11, 1 + (6 - d.weekday()) % 7, 2)
    return start <= dt < end


def _localize(dt, zone):
    if zone is None:  # sender unknown: an offset-less time cannot be resolved -> null
        return None
    name = "America/New_York" if zone == "E" else "America/Chicago"
    if ZoneInfo is not None:
        try:
            tz = _TZ.get(name)
            if tz is None:
                tz = _TZ[name] = ZoneInfo(name)
            return dt.replace(tzinfo=tz).astimezone(timezone.utc)
        except Exception:
            pass
    off = (-5 if zone == "E" else -6) + (1 if _is_dst(dt) else 0)
    return (dt - timedelta(hours=off)).replace(tzinfo=timezone.utc)


def parse_ts(s, zone):
    if not isinstance(s, str):
        return None
    s = s.strip()
    if not s:
        return None
    try:
        m = DTM_RE.fullmatch(s)
        if m:
            y, mo, d, h, mi, sec, tz = m.groups()
            dt = datetime(int(y), int(mo), int(d), int(h), int(mi), int(sec or 0))
            if tz:
                if tz == "Z":
                    return dt.replace(tzinfo=timezone.utc)
                sign = -1 if tz[0] == "-" else 1
                dg = tz[1:].replace(":", "")
                off = timedelta(hours=int(dg[:2]), minutes=int(dg[2:4]) if len(dg) > 2 else 0)
                return (dt - sign * off).replace(tzinfo=timezone.utc)
            return _localize(dt, zone)
        if len(s) < 16:
            return None
        dt = datetime.fromisoformat(s.replace("Z", "+00:00"))
        if dt.tzinfo is None:
            return _localize(dt, zone)
        return dt.astimezone(timezone.utc)
    except (ValueError, OverflowError):
        return None


def fmt_ts(dt):
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ") if dt else None


def sender_zone(msh3, msh4, acc):
    # `connection` / `received_at` are engine bookkeeping: never used for the zone
    blob = re.sub(r"[-_]", " ", f"{msh3} {msh4}".lower())
    if "ref" in blob or re.search(r"\brl\b", blob) or acc.startswith("RL"):
        return "C"
    m4 = msh4.strip().upper()
    if m4 == "HOSP" or (not m4 and acc.startswith("LAB")):
        return "E"
    return "C" if m4 else None


# ------------------------------------------------------------ field parsers
NULL_STRINGS = {"", "null", "none", "n/a", "na", "nan", "-", "--"}
NUM_RE = re.compile(r"[-+]?\d+(?:\.\d+)?(?:[eE][-+]?\d+)?")


def parse_value(v, flag):
    if flag.strip() in ("<", ">"):
        return None
    v = hl7u(v).strip()
    if v.lower() in NULL_STRINGS or v[0] in "<>":
        return None
    if "^" in v:  # structured numeric: comparator^number
        parts = v.split("^")
        if parts[0].strip() in ("<", ">", "<=", ">="):
            return None
        v = (parts[1] if len(parts) > 1 and parts[1].strip() else parts[0]).strip()
    s = v.replace(" ", "")
    if re.fullmatch(r"[-+]?\d{1,3}(?:,\d{3})+(?:\.\d+)?", s):
        s = s.replace(",", "")
    elif re.fullmatch(r"[-+]?\d+,\d+", s):
        s = s.replace(",", ".")
    if not NUM_RE.fullmatch(s):
        return None
    try:
        d = Decimal(s)
    except InvalidOperation:
        return None
    if not d.is_finite() or d < 0:
        return None
    return format(d.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP), "f")


THOU_RE = re.compile(r"x?10(?:\*\*|\*|\^|e)?3/(?:u|mc)l|(?:k|thou|kcell)/(?:u|mc)l")
UNIT_MAP = {"mg/dl": "mg/dL", "mg%": "mg/dL", "mmol/l": "mmol/L", "meq/l": "mmol/L", "g/dl": "g/dL"}


def _unit_key(u):
    return u.lower().replace(" ", "").replace("\u00b5", "u").replace("\u03bc", "u")


def _unit_lookup(u):
    k = _unit_key(u)
    if THOU_RE.fullmatch(k):
        return "10*3/uL"
    return UNIT_MAP.get(k)


def norm_unit(raw):
    u = hl7u(raw).strip()
    if not u:
        return None
    r = _unit_lookup(u)
    if r:
        return r
    if "^" in u:
        u = u.split("^")[0].strip()
        r = _unit_lookup(u)
        if r:
            return r
    u = u.replace("\u00b5", "u").replace("\u03bc", "u")
    return u or None


def _cx(field):
    out = []
    for rep in field.split("~"):
        c = rep.split("^")
        pid = c[0].strip()
        auth = c[3].split("&")[0].strip().upper() if len(c) > 3 else ""
        typ = c[4].strip().upper() if len(c) > 4 else ""
        out.append((pid, auth, typ))
    return out


def pick_pid(pid_seg):
    if not pid_seg:
        return None
    items = _cx(g(pid_seg, 3)) + _cx(g(pid_seg, 2))
    ok = [(p, a, t) for p, a, t in items if re.fullmatch(r"\d{8}", p)]
    for cond in (lambda a, t: a == "HOSP" and t == "MR",
                 lambda a, t: a == "HOSP" and t == "",
                 lambda a, t: a == "" and t in ("", "MR")):
        for p, a, t in ok:
            if cond(a, t):
                return p
    return None


# ------------------------------------------------------------------ handler
class Handler:
    def __init__(self):
        self.groups = {}
        self.seen = set()
        self.merge = {}
        self.n = 0

    # -- parse one log line into a candidate entry (or None)
    def _parse(self, raw):
        ex = extract(raw)
        if ex is None:
            return None
        msg, trunc, conn = ex
        i = msg.find("MSH|")
        if i < 0:
            return None
        s = fix_layers(msg[i:])
        digest = hashlib.md5(s.encode("utf-8", "ignore")).digest()
        if digest in self.seen:
            return None
        self.seen.add(digest)

        segs = split_segments(s)
        parsed, obxs = {}, []
        for k, seg in enumerate(segs):
            f = seg.lstrip("\ufeff \t").split("|")
            if trunc and k == len(segs) - 1:
                f = f[:-1]  # the last field of a cut line cannot be trusted
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

        pid_seg = parsed.get("PID")
        pid = pick_pid(pid_seg)

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
            return None  # a garbled key would be a row that should not exist (-2)

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
        return {
            "key": (acc, test),
            "acc": acc, "test": test, "pid": pid, "val": val,
            "unit": norm_unit(g(obx, 6)),
            "obs": fmt_ts(parse_ts(g(obr, 7).split("^")[0], zone)),
            "st": st, "ts": parse_ts(g(msh, 6), zone),
            "trunc": trunc, "seq": self.n,
        }

    def process(self, raw):
        try:
            e = self._parse(raw)
            if e is not None:
                self.groups.setdefault(e.get("key"), []).append(e)
        except Exception:
            pass
        return []  # everything is emitted once, in finalize()

    # -- pick the winning candidate for one key
    @staticmethod
    def _resolve(entries):
        entries = sorted(entries, key=lambda e: (e["ts"] or MIN_TS, e["seq"]))
        cands, last = [], None
        for e in entries:
            if e["st"] == "U":
                if e["val"] is not None or last is None:
                    c = dict(e, st="final")
                elif last["st"] == "preliminary":
                    c = dict(last, st="final", ts=e["ts"], seq=e["seq"])
                else:
                    continue
                cands.append(c)
                last = c
                continue
            cands.append(e)
            if e["val"] is not None and e["st"] != "W":
                last = e
        if not cands:
            return None
        return max(cands, key=lambda c: (not c["trunc"], RANK.get(c["st"], 0),
                                         c["ts"] or MIN_TS, c["seq"]))

    def _final_pid(self, p):
        if not APPLY_MERGES or p is None:
            return p
        seen = set()
        while p in self.merge and p not in seen:
            seen.add(p)
            p = self.merge[p]
        return p

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

## Code after — proposed change

```python
class Handler:
    def __init__(self):
        self.groups = {}  # key -> minimum history proven necessary
        self.seen = set()  # keep only if global deduplication is required
        self.merge = {}  # retired patient ID -> surviving patient ID
        self.n = 0

    def process(self, raw: str) -> list[dict]:
        for candidate in self._parse_all_results(raw):
            key = candidate['key']
            state = self.groups.get(key)
            # This reducer must preserve current _resolve() semantics:
            # status rank, timestamp, sequence, withdrawals and truncation.
            state = self._reduce_equivalently(state, candidate)
            if state is not None:
                self.groups[key] = state
        return []

    def finalize(self) -> list[dict]:
        # Apply chart merges, resolve winners, then emit the exact schema.
        return self._emit_resolved_rows()
```

This is an architecture contract, not drop-in code. _parse_all_results, _reduce_equivalently, and _emit_resolved_rows must be implemented and tested against the existing resolver before replacement. The first lower-risk experiment is to compact candidate representation and measure memory. Compact tuples alone may not suffice while candidate count and the fingerprint set still grow.

Validation: compare new reducer against the old resolver over generated short histories with status/timestamp/sequence permutations; one message with multiple eligible OBX segments yields one candidate per result; preserve preliminary-to-final, corrected, W withdrawal, duplicate, truncation, late-message, and MRN-merge behavior; measure memory at 10k, 100k, and 1M records and keep below 512 MB with margin; confirm finalize() completes.

## Learning notes

- The README's score, row counts, and named stream conditions are evidence; root-cause prioritization is an engineering assessment unless controlled tests prove it.
- Make one architectural change at a time, then compare exact output values and row counts against the task contract.
- Do not treat a proposal as drop-in code until all referenced helpers, constants, and dependencies are present and the full challenge test passes.
- Keep memory, identity/deduplication, event-time ordering, status precedence, and output lifecycle as separate invariants; optimizing one must not silently break another.
