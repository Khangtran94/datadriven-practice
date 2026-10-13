# Week 1: The Handoff: `handler.py` vs `gold_submit.py`

**Your score:** 0.5159 · **Rank:** #8 of 11 (top 73%) · **Points:** +20
**Records recovered:** 821,962 of 951,089 · **Work per record:** 1.2x median · **Statements:** 40
**Context:** a retired CRM's nightly export (1 JSON object per customer, written by 3 generations of exporter) has to become 1 clean row per customer: `customer_id, email, signup_at, plan, seats, mrr_usd`.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

**Evidence tags:** `[measured]` from the README · `[estimate]` from my local run of your handler, the gold file and the proposed handler on hand-built inputs (not the real stream) · `[inferred]` from reading the code · `[untested]` proposed code I could not run.

> **How this file works.** Every section shows your code verbatim (**Before**), the proposed code (**After**), a plain-language **How it works**, and a **Proof** table where I ran all three handlers on the same example input. The complete proposed handler is at the end.

---

## Impact ranking

| # | Area | Evidence from README | Gap vs gold |
|---|---|---|---|
| 1 | Rows emitted twice | 854,938 second rows = **1,709,876 points** `[measured]` | `process` and `finalize` both emit |
| 2 | `customer_id` gate and key aliases | `customer_id` missed 129,127 (every column inherits it) | Strict `C-` + 7 digits, one key name |
| 3 | Epoch milliseconds crash the record | `signup_at` missed 192,378 | One bad field kills all six columns |
| 4 | Email display names and `mailto:` | `email` wrong 20,857 | Whole string is kept, not the address |
| 5 | Seats and MRR formats | missed 180,101 and 175,719 | `int()` / `float()` on human-formatted text |
| 6 | Broken JSON | 6.0% of stream, 12% recovered | Strict `json.loads` only |
| 7 | Mixed date formats | 8.0%, 75% recovered; `signup_at` wrong 585 | Covered in section 3 |
| 8 | Plan aliases | 6.0%, 69% recovered | Gold's first-word rule |
| 9 | Nesting and localized keys | 10.0% (51%) and 5.0% (2%) | Beyond gold: gold does not handle nesting either |

---

## 1. Rows emitted twice

**Your code**: `process` returns every row and `finalize` returns them all again; `customers` is also a class attribute shared by every instance.

**Gold code**: `gold_submit.py` L258–270: `process` returns `[row]`, `finalize` returns `[]`. It emits each line once, with no de-duplication.

**Example input**: 1,000 valid customers, plus 40 of the same lines sent again.

**Your behavior**: each customer is emitted once by `process` and again by `finalize`, so every key has at least two rows.

**Gold behavior**: one row per line, so the 40 re-sent lines become 40 second rows.

**Why it matters**: the README says 854,938 rows were a second row for a key already emitted, costing 1,709,876 points `[measured]`. That is larger than any column miss.

**Before** (`handler.py`)
```python
  5      customers = {}
...
 63              Handler.customers[customer_id] = row
 64              return [row]
...
 68      def finalize(self):
 69          return list(Handler.customers.values())
```

**After**
```python
class Handler:
    def __init__(self):
        self.rows = {}                                  # instance state, not a class attribute

    def process(self, raw):
        try:
            rec = parse_line(raw)
            row = clean_record(rec) if rec is not None else None
            if row:
                old = self.rows.get(row["customer_id"])
                if old:                                 # a later line wins field by field; None never erases a value
                    row = {k: (v if v is not None else old[k]) for k, v in row.items()}
                self.rows[row["customer_id"]] = row
        except Exception:
            pass
        return []                                       # never emit here

    def finalize(self):
        return list(self.rows.values())
```

**How it works**: `process` only collects: it keeps the latest value per customer in a dictionary that belongs to the handler instance, and returns `[]`. `finalize` then writes each customer once. When a customer appears twice, the later line wins field by field and a missing value never erases a real one.

**Proof** `[estimate]`: 1,000 customers + 40 re-sent lines.

| Handler | Rows emitted | Distinct keys | Second rows |
|---|---:|---:|---:|
| Before | 2,040 | 1,000 | **1,040** |
| After | 1,000 | 1,000 | **0** |
| Gold | 1,040 | 1,000 | 40 |

---

## 2. `customer_id` gate and key aliases

**Your code**: only the key `customer_id`, then a strict `C-` + 7-digit check; anything else returns `[]`.

**Gold code**: `gold_submit.py` L73–82, L232–238: it reads `customer_id`, `customerId` and `id`, turns integers into text, trims, uppercases and removes whitespace, and only checks that the result is non-blank.

**Example input**: `{"customerId":" c-0001234 ","plan":"pro"}` and `{"id":1234567,"plan":"team"}`.

**Your behavior**: both lines produce no row, so the whole customer (all six columns) is lost.

**Gold behavior**: both produce a row.

**Why it matters**: `customer_id` is the key. `customer_id` missed 129,127 `[measured]`, and every other column inherits those misses.

**Before** (`handler.py` L11–25)
```python
 11              customer_id = record.get('customer_id')
 12              if isinstance(customer_id, str):
 13                  customer_id = customer_id.strip().upper()
 14                  # parts = customer_id.split("-", 1)
 15                  # if (len(parts) == 2 and parts[0] == "C" and len(parts[1]) == 7 and parts[1].isdigit()):
 16                  if (customer_id.startswith('C-') and len(customer_id) == 9 and customer_id[2:].isdigit()):
 17                      # valid customer_id
 18                      pass
 19                  else:
 20                      customer_id = None
 21              else:
 22                  customer_id = None 
 23              #### invalid customer_id
 24              if customer_id is None:
 25                  return []             
```

**After**
```python
ALIASES = {                                   # normalized key name -> field
    "customer_id": {"customerid", "id", "custid", "cid"},
    "email": {"email", "emailaddress", "mail"},
    "signup": {"signupts", "signupat", "signupdate", "signup", "createdat"},
    "plan": {"plan", "plantier", "tier"},
    "seats": {"seats", "seatcount", "numseats"},
    "mrr": {"mrr", "mrrusd", "monthlyrevenue"},
}

LOOKUP = {a: f for f, names in ALIASES.items() for a in names}

def flatten(obj, depth=0):                              # pull fields out of sub-objects, top level wins
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat

def canonical(rec):                                     # field -> first value that is not a null spelling
    out = {}
    for k, v in flatten(rec).items():
        field = LOOKUP.get(re.sub(r"[^a-z0-9]", "", str(k).lower()))
        if field and field not in out and not is_null(v):
            out[field] = v
    return out

def clean_id(v):
    if isinstance(v, bool) or isinstance(v, (dict, list)):
        return None
    if isinstance(v, float) and not v.is_integer():
        return None
    s = re.sub(r"\s+", "", str(int(v) if isinstance(v, float) else v)).upper()
    m = re.fullmatch(r"C-?(\d{7})", s)
    if m:
        return "C-" + m.group(1)
    return s if re.fullmatch(r"[A-Z0-9_-]{3,}", s) and any(c.isdigit() for c in s) else None
```

**How it works**: key names are compared after removing punctuation and case, so `customerId`, `customer_id` and `id` all reach the same field. Null spellings (`"N/A"`, `"null"`) are skipped, so a later valid alias can still fill the slot. An id such as `c-0001234` or `C0001234` is rebuilt as `C-0001234`; other non-blank ids are kept instead of dropped.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| id: customerId, padded, lowercase | `pro` | ✘ <no row> | ✔ pro | ✔ pro |
| id: numeric id | `team` | ✘ <no row> | ✔ team | ✔ team |

---

## 3. Epoch milliseconds crash the whole record (and mixed date formats)

**Your code**: seconds-only epoch, and a bare `except:` that drops the whole record when anything fails.

**Gold code**: `gold_submit.py` L129–170: numbers by magnitude (seconds, ms, µs), numeric strings, ISO with offsets, US dates (month first unless impossible), compact `YYYYMMDD`; naive times are UTC.

**Example input**: `"signup_ts": 1735689600000` (ms), `"1735689600"` (epoch as a string), `"2025-01-01 10:00:00"` (no zone), `"01/15/2025"`.

**Your behavior**: the millisecond value makes `datetime.fromtimestamp` raise `ValueError` (year out of range). Nothing catches it locally, so the bare `except:` returns `[]` and the entire customer disappears. The string epoch and the US date become `None`.

**Gold behavior**: all four parse.

**Why it matters**: `signup_at` missed 192,378 and was wrong 585 times `[measured]`. The crash path also loses the other five columns for those customers.

**Before** (`handler.py` L27–38 and L65–66)
```python
 27              signup_ts = record.get('signup_ts')
 28              if isinstance(signup_ts, (int,float)):
 29                  signup_at = datetime.fromtimestamp(signup_ts, tz = timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
 30              elif isinstance(signup_ts, str):
 31                  ### case string
 32                  try: 
 33                      dt = datetime.fromisoformat(signup_ts.replace("Z", "+00:00"))
 34                      signup_at = dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
 35                  except ValueError:
 36                      signup_at = None
 37              else:
 38                  signup_at = None
...
 65          except:
 66              return []
```

**After**
```python
def _utc(y, mo, d, hh=0, mm=0, ss=0, tz=None):
    try:
        off = timedelta(0)
        if tz and tz.upper() != "Z":
            digits = tz[1:].replace(":", "")
            off = (1 if tz[0] == "+" else -1) * timedelta(hours=int(digits[:2]), minutes=int(digits[2:] or 0))
        dt = datetime(int(y), int(mo), int(d), int(hh or 0), int(mm or 0), int(ss or 0), tzinfo=timezone(off))
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, OverflowError):
        return None

def clean_signup(v):
    if isinstance(v, bool) or isinstance(v, (dict, list)):
        return None
    if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
        v = float(v)                                    # epoch written as a string
    if isinstance(v, (int, float)):
        n = float(v)
        if n <= 0:
            return None
        n = n / 1e6 if n >= 1e14 else n / 1e3 if n >= 1e11 else n      # microseconds / milliseconds / seconds
        try:
            return datetime.fromtimestamp(n, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OverflowError, OSError, ValueError):
            return None
    if not isinstance(v, str):
        return None
    s = v.strip()
    m = ISO_RE.fullmatch(s)
    if m:
        y, mo, d, hh, mm, ss, tz = m.groups()
        return _utc(y, mo, d, hh, mm, ss, tz)          # no zone -> UTC (never the machine's local zone)
    m = US_RE.fullmatch(s)
    if m:
        a, b, y, hh, mm, ss = m.groups()
        mo, d = (int(a), int(b)) if int(a) <= 12 else (int(b), int(a))   # month first unless it cannot be
        return _utc(y, mo, d, hh, mm, ss)
    m = re.fullmatch(r"(\d{4})(\d{2})(\d{2})", s)
    return _utc(*m.groups()) if m else None
```

**How it works**: each field has its own function, so a failure only nulls that field. A number is read by size: at or above 1e14 it is microseconds, at or above 1e11 milliseconds, otherwise seconds. A time with no zone is read as UTC (never the machine's local zone). A date such as `01/15/2025` is read month first unless the first number is above 12.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| signup: epoch milliseconds | `2025-01-01T00:00:00Z` | ✘ <no row> | ✔ 2025-01-01T00:00:00Z | ✔ 2025-01-01T00:00:00Z |
| signup: epoch as string | `2025-01-01T00:00:00Z` | ✘ None | ✔ 2025-01-01T00:00:00Z | ✔ 2025-01-01T00:00:00Z |
| signup: no zone (read as UTC) | `2025-01-01T10:00:00Z` | ✔ 2025-01-01T10:00:00Z | ✔ 2025-01-01T10:00:00Z | ✔ 2025-01-01T10:00:00Z |
| signup: US date | `2025-01-15T00:00:00Z` | ✘ None | ✔ 2025-01-15T00:00:00Z | ✔ 2025-01-15T00:00:00Z |

> The no-zone row passes for your handler only because my sandbox runs in UTC. `astimezone()` on a naive time uses the machine's local zone (L34), so on another machine it would shift the time `[inferred]`. That is a plausible source of the 585 wrong values.

---

## 4. Email display names and `mailto:`

**Your code**: strips and lowercases the whole string if it contains one `@`.

**Gold code**: `gold_submit.py` L85–95: strips `mailto:`, extracts the address with a regex, lowercases it.

**Example input**: `"Jane Doe <Jane@Example.COM>"` and `"mailto:jane@example.com"`.

**Your behavior**: both contain one `@`, so you return the whole string lowercased: `jane doe <jane@example.com>` and `mailto:jane@example.com`. Those are wrong values, not nulls.

**Gold behavior**: both become `jane@example.com`.

**Why it matters**: `email` was wrong 20,857 times `[measured]`.

**Before** (`handler.py` L56)
```python
 56                  "email": record.get("email").strip().lower() if isinstance(record.get("email"), str) and record.get("email").count('@') == 1 else None,
```

**After**
```python
def clean_email(v):
    if not isinstance(v, str):
        return None
    m = EMAIL_RE.search(re.sub(r"^\s*mailto:", "", v.strip(), flags=re.I))
    return m.group(0).lower() if m else None
```

**How it works**: remove a leading `mailto:`, search for the address inside the text, and lowercase only that address.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| email: display name | `jane@example.com` | ✘ jane doe <jane@example.com> | ✔ jane@example.com | ✔ jane@example.com |
| email: mailto: | `jane@example.com` | ✘ mailto:jane@example.com | ✔ jane@example.com | ✔ jane@example.com |

---

## 5. Seats and MRR formats

**Your code**: `int(seats)` and `round(float(mrr), 2)` directly on the raw value.

**Gold code**: `gold_submit.py` L186–228: strips commas, symbols and units, rejects non-whole seat counts, rounds MRR with `Decimal` half-even. It removes every comma, so a European decimal comma is read wrongly.

**Example input**: `"seats":"1,200"`, `"12 seats"`, `2.7`; `"mrr":"$1,299.50"`, `"1.234,50"`.

**Your behavior**: `int("1,200")`, `int("12 seats")` and `float("$1,299.50")` raise and become `None`. `int(2.7)` silently truncates to 2.

**Gold behavior**: 1200, 12, `None` for 2.7 and 1299.5, but `1.234,50` becomes 1.23.

**Why it matters**: `seats` missed 180,101 and `mrr_usd` missed 175,719, both with 0 wrong `[measured]`, so the loss is all failed parses and dropped records.

**Before** (`handler.py` L42–52)
```python
 42              seats = record.get('seats')
 43              try:
 44                  seats = int(seats) if seats is not None else None
 45              except (ValueError, TypeError):
 46                  seats = None
 47                  #### mrr
 48              mrr = record.get('mrr')
 49              try:
 50                  mrr_usd = round(float(mrr),2) if mrr is not None else None
 51              except (ValueError, TypeError):
 52                  mrr_usd = None
```

**After**
```python
def to_number(v):                                       # "1,200"  "$1,299.50"  "12 seats"  "1.234,50"
    if isinstance(v, bool):
        return None
    try:
        if isinstance(v, (int, float)):
            d = Decimal(str(v))
        else:
            s = re.sub(r"[^\d,.+\-]", "", str(v))
            if not re.search(r"\d", s):
                return None
            if "," in s and "." in s:                    # the separator that comes last is the decimal point
                s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
            elif "," in s:
                s = s.replace(",", "") if re.fullmatch(r"[-+]?\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
            d = Decimal(s)
        return d if d.is_finite() else None
    except InvalidOperation:
        return None

def clean_seats(v):
    d = to_number(v)
    return int(d) if d is not None and d == d.to_integral_value() and d >= 0 else None

def clean_mrr(v):
    d = to_number(v)
    return float(d.quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)) if d is not None and d >= 0 else None
```

**How it works**: letters and currency symbols are stripped. If both `,` and `.` appear, the one that comes last is the decimal point. A lone comma followed by exactly three digits is a thousands separator; otherwise it is a decimal comma. A seat count must be a whole number; MRR is rounded to cents with `Decimal`.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| seats: '1,200' | `1200` | ✘ None | ✔ 1200 | ✔ 1200 |
| seats: '12 seats' | `12` | ✘ None | ✔ 12 | ✔ 12 |
| seats: 2.7 (not a whole number) | `None` | ✘ 2 | ✔ None | ✔ None |
| mrr: EU decimal comma '1.234,50' | `1234.5` | ✘ None | ✔ 1234.5 | ✘ 1.23 |
| mrr: '$1,299.50' | `1299.5` | ✘ None | ✔ 1299.5 | ✔ 1299.5 |

> The European-comma case goes beyond gold, which reads it wrongly.

---

## 6. Broken JSON

**Your code**: a single strict `json.loads(raw)`; any failure goes to the bare `except:` and drops the line.

**Gold code**: `gold_submit.py` L38–63: strips the BOM, decodes a second time when the result is a string, slices from the first `{` to the last `}`, and removes trailing commas.

**Example input**: a BOM line, `{"customer_id":"C-0000012","plan":"pro",}` (trailing comma), and a double-encoded line.

**Your behavior**: all three raise and the line is dropped.

**Gold behavior**: all three are recovered.

**Why it matters**: broken JSON is 6.0% of the stream and only 12% was recovered `[measured]`.

**Before** (`handler.py` L8)
```python
  8              record = json.loads(raw)
```

**After**
```python
def parse_line(raw):
    s = raw.strip().lstrip("\ufeff") if isinstance(raw, str) else ""
    if not s:
        return None
    try:
        obj = json.loads(s, strict=False)
        if isinstance(obj, str):                       # JSON written as a quoted string
            obj = json.loads(obj, strict=False)
        return obj if isinstance(obj, dict) else None
    except ValueError:
        pass
    a, b = s.find("{"), s.rfind("}")                   # junk before/after, trailing commas
    if a >= 0 and b > a:
        try:
            obj = json.loads(re.sub(r",\s*([}\]])", r"\1", s[a:b + 1]), strict=False)
            return obj if isinstance(obj, dict) else None
        except ValueError:
            return None
    return None
```

**How it works**: strip the BOM, parse with `strict=False` (also accepts a tab typed inside a string), decode again if the result is a string, and as a fallback slice out the `{...}` span and drop trailing commas.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| json: BOM | `pro` | ✘ <no row> | ✔ pro | ✔ pro |
| json: trailing comma | `pro` | ✘ <no row> | ✔ pro | ✔ pro |
| json: double-encoded | `pro` | ✘ <no row> | ✔ pro | ✔ pro |

> Truncated lines (0.8% of the stream, 2% recovered `[measured]`) are not recovered by any of the three. The README says everything before the cut is real, so a field-by-field salvage is a possible next step `[untested]`.

---

## 7. Mixed date formats

Covered by section 3: the same `clean_signup` handles ISO with or without a zone, offsets, US dates and epochs. The README says an ambiguous date resolves only by the source's own rule. Month-first is a guess carried over from the top submission; check it against the sample.

---

## 8. Plan aliases

**Your code**: the lowercased plan must be exactly one of `pro`, `free`, `team`, `enterprise`.

**Gold code**: `gold_submit.py` L173–183: exact match, otherwise the first alphabetic word. Renamed aliases such as `business` stay null in gold too.

**Example input**: `"Pro Plan"`, `"team-annual"`, `" PRO "`, `"business"`.

**Your behavior**: `pro plan` and `team-annual` become `None`; ` PRO ` works.

**Gold behavior**: `pro`, `team`, `pro`, `None`.

**Why it matters**: plan aliases are 6.0% of the stream (69% recovered), with 174 wrong `[measured]`. This is the smallest gap.

**Before** (`handler.py` L40 and L58)
```python
 40              plan = record.get('plan').strip().lower() if isinstance(record.get('plan'),str) else None
...
 58                  "plan": plan if plan in ['pro','free','team','enterprise'] else None,
```

**After**
```python
def clean_plan(v):
    if not isinstance(v, str):
        return None
    s = v.strip().lower()
    if s in PLANS:
        return s
    tok = re.split(r"[^a-z]+", s)[0]
    return tok if tok in PLANS else None
```

**How it works**: after trimming and lowercasing, accept an exact match, otherwise try the first word. Anything else is null, as before.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| plan: 'Pro Plan' | `pro` | ✘ None | ✔ pro | ✔ pro |
| plan: 'team-annual' | `team` | ✘ None | ✔ team | ✔ team |

---

## 9. Nesting and localized keys (beyond gold)

**Your code**: each field is read from one top-level key (`record.get('customer_id')`, `'signup_ts'`, `'plan'`, `'seats'`, `'mrr'`, `'email'`).

**Gold code**: reads only top-level keys, with a handful of aliases.

**Example input**: `{"customer_id":"C-0000016","billing":{"plan":"pro","seats":5}}`.

**Your behavior**: `seats` is `None`, because the field sits inside `billing`.

**Gold behavior**: `seats` is `None` as well, so gold does not handle nesting.

**Why it matters**: nesting is 10.0% of the stream (51% recovered) and localized key names 5.0% (2% recovered) `[measured]`.

**Before** (`handler.py` L42, L48)
```python
 42              seats = record.get('seats')
 48              mrr = record.get('mrr')
```

**After**: `flatten` and `canonical` from section 2. Localized labels are not handled; add them to `ALIASES` once you see them in the sample `[untested]`.

**How it works**: values inside sub-objects are pulled up to one flat dictionary (top-level keys win), then looked up by normalized key name.

**Proof** `[estimate]`

| Case | Expected | Before | After | Gold |
|---|---|---|---|---|
| nested: billing sub-object | `5` | ✘ None | ✔ 5 | ✘ None |

---

## Recommended pattern

`process()` collects, `finalize()` emits once. The full proposed handler (every After above, assembled) follows. Run it against the sample before submitting.

<details>
<summary>Complete proposed <code>handler.py</code></summary>

```python
import json
import re
from datetime import datetime, timedelta, timezone
from decimal import Decimal, InvalidOperation, ROUND_HALF_EVEN

PLANS = {"free", "pro", "team", "enterprise"}
NULLS = {"", "null", "none", "n/a", "na", "nan", "nil", "undefined", "missing", "-", "--", "unknown"}

ALIASES = {                                   # normalized key name -> field
    "customer_id": {"customerid", "id", "custid", "cid"},
    "email": {"email", "emailaddress", "mail"},
    "signup": {"signupts", "signupat", "signupdate", "signup", "createdat"},
    "plan": {"plan", "plantier", "tier"},
    "seats": {"seats", "seatcount", "numseats"},
    "mrr": {"mrr", "mrrusd", "monthlyrevenue"},
}
LOOKUP = {a: f for f, names in ALIASES.items() for a in names}
EMAIL_RE = re.compile(r"[A-Z0-9._%+\-]+@[A-Z0-9.\-]+\.[A-Z]{2,}", re.I)
ISO_RE = re.compile(r"(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2})(?::(\d{2}))?)?(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?", re.I)
US_RE = re.compile(r"(\d{1,2})[/-](\d{1,2})[/-](\d{4})(?:[ T](\d{1,2}):(\d{2})(?::(\d{2}))?)?")


def is_null(v):
    return v is None or (isinstance(v, str) and v.strip().lower() in NULLS)


# ---- 1. read one line of JSON, even when it is damaged ------------------------------
def parse_line(raw):
    s = raw.strip().lstrip("\ufeff") if isinstance(raw, str) else ""
    if not s:
        return None
    try:
        obj = json.loads(s, strict=False)
        if isinstance(obj, str):                       # JSON written as a quoted string
            obj = json.loads(obj, strict=False)
        return obj if isinstance(obj, dict) else None
    except ValueError:
        pass
    a, b = s.find("{"), s.rfind("}")                   # junk before/after, trailing commas
    if a >= 0 and b > a:
        try:
            obj = json.loads(re.sub(r",\s*([}\]])", r"\1", s[a:b + 1]), strict=False)
            return obj if isinstance(obj, dict) else None
        except ValueError:
            return None
    return None


def flatten(obj, depth=0):                              # pull fields out of sub-objects, top level wins
    flat = {}
    for k, v in obj.items():
        if isinstance(v, dict) and depth < 3:
            for k2, v2 in flatten(v, depth + 1).items():
                flat.setdefault(k2, v2)
        else:
            flat.setdefault(k, v)
    return flat


def canonical(rec):                                     # field -> first value that is not a null spelling
    out = {}
    for k, v in flatten(rec).items():
        field = LOOKUP.get(re.sub(r"[^a-z0-9]", "", str(k).lower()))
        if field and field not in out and not is_null(v):
            out[field] = v
    return out


# ---- 2. one small function per field: a failure only nulls that field --------------
def clean_id(v):
    if isinstance(v, bool) or isinstance(v, (dict, list)):
        return None
    if isinstance(v, float) and not v.is_integer():
        return None
    s = re.sub(r"\s+", "", str(int(v) if isinstance(v, float) else v)).upper()
    m = re.fullmatch(r"C-?(\d{7})", s)
    if m:
        return "C-" + m.group(1)
    return s if re.fullmatch(r"[A-Z0-9_-]{3,}", s) and any(c.isdigit() for c in s) else None


def clean_email(v):
    if not isinstance(v, str):
        return None
    m = EMAIL_RE.search(re.sub(r"^\s*mailto:", "", v.strip(), flags=re.I))
    return m.group(0).lower() if m else None


def _utc(y, mo, d, hh=0, mm=0, ss=0, tz=None):
    try:
        off = timedelta(0)
        if tz and tz.upper() != "Z":
            digits = tz[1:].replace(":", "")
            off = (1 if tz[0] == "+" else -1) * timedelta(hours=int(digits[:2]), minutes=int(digits[2:] or 0))
        dt = datetime(int(y), int(mo), int(d), int(hh or 0), int(mm or 0), int(ss or 0), tzinfo=timezone(off))
        return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    except (ValueError, OverflowError):
        return None


def clean_signup(v):
    if isinstance(v, bool) or isinstance(v, (dict, list)):
        return None
    if isinstance(v, str) and re.fullmatch(r"\d+(\.\d+)?", v.strip()):
        v = float(v)                                    # epoch written as a string
    if isinstance(v, (int, float)):
        n = float(v)
        if n <= 0:
            return None
        n = n / 1e6 if n >= 1e14 else n / 1e3 if n >= 1e11 else n      # microseconds / milliseconds / seconds
        try:
            return datetime.fromtimestamp(n, tz=timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
        except (OverflowError, OSError, ValueError):
            return None
    if not isinstance(v, str):
        return None
    s = v.strip()
    m = ISO_RE.fullmatch(s)
    if m:
        y, mo, d, hh, mm, ss, tz = m.groups()
        return _utc(y, mo, d, hh, mm, ss, tz)          # no zone -> UTC (never the machine's local zone)
    m = US_RE.fullmatch(s)
    if m:
        a, b, y, hh, mm, ss = m.groups()
        mo, d = (int(a), int(b)) if int(a) <= 12 else (int(b), int(a))   # month first unless it cannot be
        return _utc(y, mo, d, hh, mm, ss)
    m = re.fullmatch(r"(\d{4})(\d{2})(\d{2})", s)
    return _utc(*m.groups()) if m else None


def clean_plan(v):
    if not isinstance(v, str):
        return None
    s = v.strip().lower()
    if s in PLANS:
        return s
    tok = re.split(r"[^a-z]+", s)[0]
    return tok if tok in PLANS else None


def to_number(v):                                       # "1,200"  "$1,299.50"  "12 seats"  "1.234,50"
    if isinstance(v, bool):
        return None
    try:
        if isinstance(v, (int, float)):
            d = Decimal(str(v))
        else:
            s = re.sub(r"[^\d,.+\-]", "", str(v))
            if not re.search(r"\d", s):
                return None
            if "," in s and "." in s:                    # the separator that comes last is the decimal point
                s = s.replace(",", "") if s.rfind(".") > s.rfind(",") else s.replace(".", "").replace(",", ".")
            elif "," in s:
                s = s.replace(",", "") if re.fullmatch(r"[-+]?\d{1,3}(,\d{3})+", s) else s.replace(",", ".")
            d = Decimal(s)
        return d if d.is_finite() else None
    except InvalidOperation:
        return None


def clean_seats(v):
    d = to_number(v)
    return int(d) if d is not None and d == d.to_integral_value() and d >= 0 else None


def clean_mrr(v):
    d = to_number(v)
    return float(d.quantize(Decimal("0.01"), rounding=ROUND_HALF_EVEN)) if d is not None and d >= 0 else None


def clean_record(rec):
    c = canonical(rec)
    cid = clean_id(c["customer_id"]) if "customer_id" in c else None
    if cid is None:
        return None
    return {
        "customer_id": cid,
        "email": clean_email(c.get("email")),
        "signup_at": clean_signup(c.get("signup")),
        "plan": clean_plan(c.get("plan")),
        "seats": clean_seats(c.get("seats")),
        "mrr_usd": clean_mrr(c.get("mrr")),
    }


# ---- 3. emit each customer exactly once, from finalize ------------------------------
class Handler:
    def __init__(self):
        self.rows = {}                                  # instance state, not a class attribute

    def process(self, raw):
        try:
            rec = parse_line(raw)
            row = clean_record(rec) if rec is not None else None
            if row:
                old = self.rows.get(row["customer_id"])
                if old:                                 # a later line wins field by field; None never erases a value
                    row = {k: (v if v is not None else old[k]) for k, v in row.items()}
                self.rows[row["customer_id"]] = row
        except Exception:
            pass
        return []                                       # never emit here

    def finalize(self):
        return list(self.rows.values())
```

</details>

## Checklist

1. **Emit each key from one place only.** If `process` emits, `finalize` must return `[]`; if `finalize` emits, `process` returns `[]`.
2. **Never let one bad field kill the record.** Parse each field in its own function.
3. **Never use a bare `except:`.** It hides bugs and drops whole records.
4. **Read numbers by size and text by shape**: epochs by magnitude, money and counts after stripping symbols and separators.
5. **Keep state on the instance**, not on the class.
