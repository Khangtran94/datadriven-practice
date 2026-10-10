# Week 1: The Handoff: `handler.py` vs `gold_submit.py`

**Your score:** 0.5159 · **Rank:** #8 of 11 (top 73%) · **Points:** +20
**Records recovered:** 821,962 of 951,089 · **Work per record:** 1.2x median · **Statements:** 40
**Context:** a retired CRM's nightly export (1 JSON object per customer, written by 3 generations of exporter) has to become 1 clean row per customer: `customer_id, email, signup_at, plan, seats, mrr_usd`.
`gold_submit.py` is the top-1 submission for this competition. Line numbers refer to the files in this folder.

---

## Impact ranking

| # | Area | Evidence from README | Gap vs gold |
|---|---|---|---|
| 1 | Rows emitted twice | 854,938 second rows = **1,709,876 points** | `process` and `finalize` both emit |
| 2 | `customer_id` gate and key aliases | `customer_id` missed 129,127 (every column inherits it) | Strict `C-` + 7 digits, one key name |
| 3 | Epoch milliseconds crash the record | `signup_at` missed 192,378 | One bad field kills all six columns |
| 4 | Email display names and `mailto:` | `email` wrong 20,857 | Whole string is kept, not the address |
| 5 | Seats and MRR formats | missed 180,101 and 175,719 | `int()` / `float()` on human-formatted text |
| 6 | Broken JSON | 6.0% of stream, 12% recovered | Strict `json.loads` only |
| 7 | Mixed date formats | 8.0%, 75% recovered; `signup_at` wrong 585 | Naive times read as machine-local |
| 8 | Plan aliases | 6.0%, 69% recovered | Small gap, gold has the same limit |
| 9 | Nesting and localized keys | 10.0% (51%) and 5.0% (2%) | Beyond gold: neither handles them |

---

## 1. Rows emitted twice

**Your code**
```python
# L63–64: process emits every row...
Handler.customers[customer_id] = row
return [row]
# L68–69: ...and finalize emits all of them again
def finalize(self):
    return list(Handler.customers.values())
```
`customers = {}` is also a class attribute (L5), shared by every instance.

**Gold code**
```python
# L258–270
def process(self, raw):
    ...
    return [row] if row else []
def finalize(self):
    return []
```

**Example input**
A normal, valid line seen once: `{"customer_id":"C-0000001","email":"a@b.com","plan":"pro",...}`

**Your behavior**
The row is returned by `process`, stored, and returned again by `finalize`. Every customer appears at least twice.

**Gold behavior**
The row is emitted once. `finalize` returns `[]`, so nothing is re-sent.

**Why it matters**
The README says 854,938 rows were a second row for a key already emitted, costing 1,709,876 points. That is larger than any column miss in the table. It matches `finalize` re-sending every customer that `process` had already emitted.

**What to change**
Emit from one place only. Keep state on the instance (`self.customers`), not on the class. Use the recommended pattern below: buffer in `process`, emit in `finalize`. The gold does not de-duplicate either, but keying by `customer_id` is free and the README lists duplicate records as 4% of the stream.

---

## 2. `customer_id` gate and key aliases

**Your code**
```python
# L11–25
customer_id = record.get('customer_id')
...
if (customer_id.startswith('C-') and len(customer_id) == 9 and customer_id[2:].isdigit()):
    pass
else:
    customer_id = None
...
if customer_id is None:
    return []
```

**Gold code**
```python
# L73–82, L232–238
def clean_customer_id(v):
    ...                       # ints -> str, strip, upper, remove inner whitespace
    return s or None
cid = clean_customer_id(first(rec.get("customer_id"), rec.get("customerId"), rec.get("id")))
```

**Example input**
- `{"customerId":" c-0001234 ","plan":"pro"}`
- `{"id":1234567,"plan":"team"}`
- `{"customer_id":"C 0001234"}`

**Your behavior**
All three return `[]`. The first two have no `customer_id` key. The third fails the `C-` prefix check. The whole customer is lost, not just the id.

**Gold behavior**
All three produce a row (`C-0001234`, `1234567`, `C0001234`). It checks only that the id is non-blank.

**Why it matters**
`customer_id` is the key, so a dropped id drops all six columns. That is why every column shows at least 129,127 missed.

**What to change**
Read `customer_id`, `customerId` and `id` with a `first(...)` helper. Strip, uppercase and remove whitespace. If the result matches `C-?(\d{7})`, rebuild it as `C-xxxxxxx`; otherwise keep it as cleaned instead of dropping the row.

---

## 3. Epoch milliseconds crash the whole record

**Your code**
```python
# L27–38
signup_ts = record.get('signup_ts')
if isinstance(signup_ts, (int,float)):
    signup_at = datetime.fromtimestamp(signup_ts, tz=timezone.utc).strftime(...)
elif isinstance(signup_ts, str):
    try:
        dt = datetime.fromisoformat(signup_ts.replace("Z", "+00:00"))
        signup_at = dt.astimezone(timezone.utc).strftime(...)
    except ValueError:
        signup_at = None
...
# L65–66
except:
    return []
```

**Gold code**
```python
# L132–155: numbers by magnitude, numeric strings, ISO regex with tz, naive -> UTC
if n >= 1e14: n /= 1e6
elif n >= 1e11: n /= 1e3
...
if s.isdigit() or re.fullmatch(r"\d+\.\d+", s):
    return clean_signup(float(s) if "." in s else int(s))
# L156–169: US dates (month first), compact yyyymmdd
```

**Example input**
- `"signup_ts": 1735689600000` (milliseconds)
- `"signup_ts": "1735689600"` (epoch as a string)
- `"signup_ts": "2025-01-01 10:00:00"` (no zone)
- `"signup_ts": "01/02/2025"`

**Your behavior**
- The milliseconds value makes `fromtimestamp` raise `ValueError` (year out of range). Nothing catches it locally, so the bare `except:` at L65 returns `[]` and the whole customer is dropped.
- The numeric string fails `fromisoformat` and becomes `None`.
- `astimezone()` on a naive datetime assumes the machine's local timezone, so the result is shifted.
- The US date becomes `None`.

**Gold behavior**
It divides by 1e3 or 1e6 by magnitude and handles numeric strings and US dates. Naive times are read as UTC.

**Why it matters**
`signup_at` missed 192,378 and was wrong 585 times. The crash path also loses the other five columns for those customers.

**What to change**
Parse each field in its own function so one failure only nulls that field. Treat numbers by magnitude (seconds, ms, µs). Read naive times as UTC. Add `MM/DD/YYYY` and `YYYYMMDD` formats.

---

## 4. Email display names and `mailto:`

**Your code**
```python
# L56
"email": record.get("email").strip().lower()
         if isinstance(record.get("email"), str) and record.get("email").count('@') == 1 else None,
```

**Gold code**
```python
# L85–95
s = re.sub(r"^mailto:", "", s, flags=re.I).strip()
m = EMAIL_RE.search(s)
return m.group(0).lower() if m else None
```

**Example input**
- `"Jane Doe <Jane@Example.COM>"`
- `"mailto:jane@example.com"`
- `"  jane@example.com  "`

**Your behavior**
The first two contain one `@`, so they pass the check. You return the entire string lowercased: `"jane doe <jane@example.com>"` and `"mailto:jane@example.com"`. Both are wrong values, not nulls.

**Gold behavior**
All three become `jane@example.com`.

**Why it matters**
This is the source of the 20,857 wrong `email` values. A wrong value is worse than a null.

**What to change**
Strip `mailto:`, extract the address with a regex, then lowercase it.

---

## 5. Seats and MRR formats

**Your code**
```python
# L42–52
seats = int(seats) if seats is not None else None
mrr_usd = round(float(mrr), 2) if mrr is not None else None
```

**Gold code**
```python
# L186–206 (seats): strip commas, Decimal, extract digits, reject non-integers
# L209–228 (mrr): strip "," "$", Decimal.quantize(0.01, ROUND_HALF_EVEN) -> f"{d:.2f}"
```

**Example input**
- `"seats": "1,200"`, `"seats": "12 seats"`, `"seats": 2.7`
- `"mrr": "$1,299.50"`, `"mrr": "1299.505"`

**Your behavior**
- `int("1,200")` and `int("12 seats")` raise and become `None`.
- `int(2.7)` silently truncates to 2.
- `float("$1,299.50")` raises and becomes `None`.
- `round(float(...), 2)` rounds a binary float.

**Gold behavior**
1,200 and 12 for seats, `None` for 2.7, and `"1299.50"` for MRR using decimal rounding.

**Why it matters**
`seats` missed 180,101 and `mrr_usd` missed 175,719. Both have 0 wrong, so the loss is all failed parses and dropped records.

**What to change**
Strip thousands separators, currency symbols and units before converting. Return `None` for non-integer seat counts. Use `Decimal` for MRR. Note that gold removes every comma, so EU decimal commas (`"1.234,50"`) are still wrong. Handling them goes beyond gold.

---

## 6. Broken JSON

**Your code**
```python
# L8
record = json.loads(raw)       # any failure -> bare except -> []
```

**Gold code**
```python
# L38–63
s = raw.strip().lstrip("\ufeff")
obj = json.loads(s)            # decode twice if the result is a str
...
chunk = s[s.find("{"): s.rfind("}") + 1]
chunk = re.sub(r",\s*([}\]])", r"\1", chunk)   # trailing commas
```

**Example input**
- A BOM line: `\ufeff{"customer_id":"C-0000001",...}`
- A trailing comma: `{"customer_id":"C-0000001","plan":"pro",}`
- Junk after the object: `{"customer_id":"C-0000001"} ;`
- A double-encoded string: `"{\"customer_id\":\"C-0000001\"}"`

**Your behavior**
All four raise inside `json.loads` and the line is dropped.

**Gold behavior**
All four are recovered.

**Why it matters**
Broken JSON is 6.0% of the stream and only 12% was recovered. The gold does not recover truncated lines (0.8%) either.

**What to change**
Strip the BOM, decode twice for double-encoded input, slice from the first `{` to the last `}`, and remove trailing commas before parsing.

---

## 7. Mixed date formats

Covered by section 3. The extra points are `fromisoformat` only (no `MM/DD/YYYY`, no compact dates) and naive strings interpreted in the machine's local zone. That is the likeliest source of the 585 wrong `signup_at` values. The README says an ambiguous date resolves only by the source's own rule. Gold uses month-first and swaps when the first number is above 12 (L160–165).

---

## 8. Plan aliases

**Your code**
```python
# L40, L58
plan = record.get('plan').strip().lower() ...
"plan": plan if plan in ['pro','free','team','enterprise'] else None
```

**Gold code**
```python
# L173–183
s = ...strip().lower()
if s in PLANS: return s
tok = re.split(r"[^a-z]+", s)[0]
return tok if tok in PLANS else None
```

**Example input**
`"Pro Plan"`, `"team-annual"`, `" PRO "`, `"business"`

**Your behavior**
`"pro plan"` and `"team-annual"` are not in the set, so they become `None`. `" PRO "` works. `"business"` is `None`.

**Gold behavior**
`pro`, `team`, `pro`, `None`. It uses the first alphabetic token. It also leaves relabelled aliases like `"business"` as null.

**Why it matters**
This is the smallest gap: plan aliases are 6.0% of the stream (69% recovered), with 174 wrong. It mostly matters for the first-token rule.

**What to change**
Add the first-token rule. Then map the aliases that actually appear in the sample (the picklist was relabelled twice) to the four contract plans.

---

## 9. Nesting and localized keys (beyond gold)

Gold reads only top-level keys with a handful of aliases (`customerId`, `id`, `email_address`, `signup_at`, `signup_date`, `created_at`, `plan_tier`, `tier`, `seat_count`, `mrr_usd`). It does not walk sub-objects or read localized labels. Nesting is 10.0% of the stream (51% recovered) and localized names are 5.0% (2% recovered). A handler that collects every nested dict and matches normalized key names, with localized labels added from the sample, would go beyond the top submission.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.customers = {}                       # instance state, never a class attribute

    def process(self, raw):
        rec = parse_json_line(raw)                # BOM, double-decode, brace slice, trailing commas
        if not rec:
            return []
        row = clean_record(rec)                   # first(...) key aliases; each clean_* isolated
        if row:                                   # so one bad field never drops the record
            old = self.customers.get(row["customer_id"])
            self.customers[row["customer_id"]] = merge(old, row)   # latest non-null wins
        return []                                 # never emit here

    def finalize(self):
        return list(self.customers.values())      # exactly one row per customer
```
