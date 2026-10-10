# Week 1 – The Handoff: handler.py vs gold_submit.py

**Your score:** 0.5159 (#8 of 11, top 73%)  
**Your file:** `handler.py`  
**Top-1 file:** `gold_submit.py`

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

854,938 rows were a second row for a key already emitted (costing ~1.7M points). Together with limited recovery on broken JSON, nesting, dates, emails, and plan aliases, this explains the 0.5159 score and 821k/951k recovered records.

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | When rows are emitted | Process returns every row **and** finalize returns the full dict → massive second-row penalty. |
| 2 | Broken / truncated JSON | 6% of stream; you recover almost none. |
| 3 | Key aliases + nesting | Localized names, nested fields, and alternate keys (10%+ of stream). |
| 4 | Signup timestamps | Epoch ms/us, mixed formats, US dates — large miss on `signup_at`. |
| 5 | Emails with display names | Angle brackets, mailto:, display names drop valid addresses. |
| 6 | Plan aliases + numbers as strings | Free-text plans and formatted money/seats lose cells. |
| 7 | Customer ID strictness | Only exact `C-#######` form; gold is more lenient. |

---

## 1. When rows are emitted

**Your code**
```python
# process ~L58–60
Handler.customers[customer_id] = row
return [row]

# finalize L63–64
def finalize(self):
    return list(Handler.customers.values())
```

**Gold code**
```python
# process → return [row] if row else []
# finalize → return []
```

**Example input**  
Two lines for the same `customer_id` (retry / duplicate export).

**Your behavior**  
`process` emits a row for each. `finalize` emits the stored row again. Harness sees two rows for the key → second-row penalty.

**Gold behavior**  
Emits the row once from `process`. `finalize` adds nothing.

**Why it matters**  
The README explicitly calls out 854,938 second rows costing 1,709,876 points. Emitting from both `process` and `finalize` is the dominant loss.

**What to change**  
Emit **only once**. Prefer the pattern used by later weeks: `process` returns `[]`, collect in instance state, emit the full set from `finalize`. Never return a row from both methods.

---

## 2. Broken / truncated JSON

**Your code**
```python
# process L7
record = json.loads(raw)
# bare except → return []
```

**Gold code**
```python
# parse_json_line
# strip BOM, try loads, then first {...} span,
# remove trailing commas, recover truncated objects
```

**Example input**  
`{"customer_id":"C-0000001", "email":"a@b.com", ...` (truncated)  
or logger prefix + object.

**Your behavior**  
`json.loads` fails → drop the whole line.

**Gold behavior**  
Recovers the first complete `{...}` object and continues.

**Why it matters**  
“Broken JSON structure” is 6% of the stream; recovered only 12%. Truncated lines are almost completely lost.

**What to change**  
Add a tolerant parser that finds the first `{`…`}` span and cleans common breakage before `json.loads`.

---

## 3. Key aliases + nesting

**Your code**
```python
# only exact keys
record.get('customer_id')
record.get('signup_ts')
record.get('plan')
record.get('seats')
record.get('mrr')
record.get('email')
```

**Gold code**
```python
# clean_record uses first(...)
cid = clean_customer_id(first(rec.get("customer_id"), rec.get("customerId"), rec.get("id")))
# similarly for email, signup_*, plan/tier, seats, mrr
```

**Example input**  
`{"id": "C-0000001", "email_address": "a@b.com", "created_at": 1609459200}`  
or `{"customer": {"id": "C-0000001", ...}}`

**Your behavior**  
Missing exact keys → `customer_id` None → early return `[]`. Nested objects ignored.

**Gold behavior**  
Tries several aliases. (Deep nesting still limited, but aliases cover a large slice.)

**Why it matters**  
Localized key names (5%) and nesting/flattening (10%) are explicit conditions with very low recovery.

**What to change**  
Maintain a small alias map (or `first` helper) for every column. Optionally flatten one level of nesting.

---

## 4. Signup timestamps

**Your code**
```python
# L27–37
if isinstance(signup_ts, (int, float)):
    signup_at = datetime.fromtimestamp(signup_ts, tz=timezone.utc)...
elif isinstance(signup_ts, str):
    dt = datetime.fromisoformat(signup_ts.replace("Z", "+00:00"))
```

**Gold code**
```python
# clean_signup
# seconds / ms / µs auto-detect
# ISO_RE + US_DATE_RE + compact yyyymmdd
# timezone handling
```

**Example input**  
`"signup_ts": 1609459200000` (millis)  
or `"signup_date": "01/01/2021 00:00"`

**Your behavior**  
Millis interpreted as seconds → year ~53000. US date fails `fromisoformat` → None.

**Gold behavior**  
Detects magnitude, parses both ISO and US forms, returns UTC ISO string.

**Why it matters**  
`signup_at` is the weakest column (80% correct, 192k missed). Epoch ms and mixed formats are called out in the conditions.

**What to change**  
Add magnitude check for epoch, plus a couple of common date patterns (US `M/D/Y`, compact `YYYYMMDD`).

---

## 5. Emails with display names

**Your code**
```python
# L48
record.get("email").strip().lower() if isinstance(...) and record.get("email").count('@') == 1 else None
```

**Gold code**
```python
# clean_email
# strip mailto:, EMAIL_RE.search, lower the match
```

**Example input**  
`"email": "Alice <alice@example.com>"`  
or `"mailto:alice@example.com"`

**Your behavior**  
`count('@')` may pass but the value is not a clean address → invalid or rejected.

**Gold behavior**  
Extracts the address with a regex and returns the clean lowercased form.

**Why it matters**  
“Emails with display names” is 4% of the stream; recovery only 72%.

**What to change**  
Use a simple email regex that searches inside the string instead of requiring the whole field to be a bare address.

---

## 6. Plan aliases + numbers as strings

**Your code**
```python
# plan L39
plan = record.get('plan').strip().lower() if ... else None
# then only if plan in ['pro','free','team','enterprise']

# seats / mrr L41–46 — int() / float() only
```

**Gold code**
```python
# clean_plan — token split on non-letters
# clean_seats — Decimal, strip commas, extract digits
# clean_mrr — strip $, commas, quantize to 0.01
```

**Example input**  
`"plan": "Pro Plan"`  
`"seats": "1,234"`  
`"mrr": "$99.50"`

**Your behavior**  
Plan becomes `"pro plan"` → not in allow-list → None. Seats/mrr fail `int`/`float`.

**Gold behavior**  
`"pro"`, `1234`, `"99.50"`.

**Why it matters**  
Plan aliases (6%) and numbers-as-strings (5%) are visible recovery gaps.

**What to change**  
Take the first alphabetic token for plan. Strip currency symbols and thousands separators before converting numbers.

---

## 7. Customer ID strictness

**Your code**
```python
# L12–18
if (customer_id.startswith('C-') and len(customer_id) == 9 and customer_id[2:].isdigit()):
    pass
else:
    customer_id = None
```

**Gold code**
```python
# clean_customer_id
# accept int/float, strip spaces, upper, return any non-blank string
```

**Example input**  
`"customer_id": "C-0000001 "` or `1234567` or `"c-0000001"`

**Your behavior**  
Fails the exact length/digit check → None → drop.

**Gold behavior**  
Cleans and keeps the id.

**Why it matters**  
`customer_id` is the strongest column but still has 129k misses. Overly strict validation drops recoverable keys.

**What to change**  
Upper-case, strip whitespace, accept the `C-` prefix optionally, and keep any plausible id rather than requiring exact length.

---

## Recommended pattern

```python
class Handler:
    def __init__(self):
        self.held = {}   # customer_id → best row

    def process(self, raw: str) -> list[dict]:
        # tolerant parse → clean fields with aliases
        # update self.held[cid] = row  (last write or merge)
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        # return the complete list of rows
        return list(self.held.values())
```

This is the architecture top solutions use on later weeks and what avoids the second-row penalty that dominated this score.
