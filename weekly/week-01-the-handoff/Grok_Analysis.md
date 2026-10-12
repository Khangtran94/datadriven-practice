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

### Your current code (before)

```python
# process
Handler.customers[customer_id] = row
return [row]                    # emits immediately

# finalize
def finalize(self):
    return list(Handler.customers.values())   # emits the same rows again
```

### Proposed change (after)

```python
class Handler:
    def __init__(self):
        self.held = {}          # customer_id → best row

    def process(self, raw: str) -> list[dict]:
        # parse + clean → update self.held[cid] = row
        # NEVER return rows here
        return []

    def finalize(self) -> list[dict]:
        return list(self.held.values())
```

### Explanation

- **Before**: every line is emitted from `process` **and** again from `finalize`. The harness treats the second emission as a duplicate row and applies a heavy penalty (−2 per extra row). That alone cost ~1.7 M points.
- **After**: `process` only updates in-memory state. All rows are emitted once, at the end, from `finalize`. No second-row penalty.

**Example input**  
Two lines for the same `customer_id` (retry / duplicate export).

**Your behavior**  
`process` emits a row for each. `finalize` emits the stored row again → second-row penalty.

**Gold behavior**  
Emits the row once (either from process or from finalize, never both).

**Why it matters**  
The README explicitly calls out 854,938 second rows. Emitting from both methods is the dominant loss.

**What to change**  
Emit **only once**. Prefer the pattern used by later weeks: `process` returns `[]`, collect in instance state, emit the full set from `finalize`.

---

## 2. Broken / truncated JSON

### Your current code (before)

```python
record = json.loads(raw)
# bare except → return []
```

### Proposed change (after)

```python
def extract_json(raw: str):
    # strip BOM, try loads
    # if fail: find first { … } span, remove trailing commas, retry
    # optionally unwrap message / data / payload once
    ...
```

### Explanation

- **Before**: any malformed or truncated line is dropped completely.
- **After**: a tolerant extractor recovers the first complete object even when the line is cut or wrapped in a logger prefix.

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

### Your current code (before)

```python
record.get('customer_id')
record.get('signup_ts')
record.get('plan')
# only exact keys
```

### Proposed change (after)

```python
def first(*vals):
    for v in vals:
        if v is not None and v != "":
            return v
    return None

cid = clean_customer_id(first(
    rec.get("customer_id"), rec.get("customerId"), rec.get("id")
))
# same pattern for email, signup_*, plan/tier, seats, mrr
```

### Explanation

- **Before**: only the exact English key names work. Localized names or nested objects are ignored → row dropped.
- **After**: a small alias list (or `first` helper) recovers the same field under several names. One-level flatten also helps.

**Example input**  
`{"id": "C-0000001", "email_address": "a@b.com", "created_at": 1609459200}`  
or `{"customer": {"id": "C-0000001", ...}}`

**Your behavior**  
Missing exact keys → `customer_id` None → early return `[]`. Nested objects ignored.

**Gold behavior**  
Tries several aliases and keeps the row.

**Why it matters**  
Localized key names (5%) and nesting/flattening (10%) are explicit conditions with very low recovery.

**What to change**  
Maintain a small alias map (or `first` helper) for every column. Optionally flatten one level of nesting.

---

## 4. Signup timestamps

### Your current code (before)

```python
if isinstance(signup_ts, (int, float)):
    signup_at = datetime.fromtimestamp(signup_ts, tz=timezone.utc)...
elif isinstance(signup_ts, str):
    dt = datetime.fromisoformat(signup_ts.replace("Z", "+00:00"))
```

### Proposed change (after)

```python
# detect magnitude: seconds / ms / µs
# also accept US dates (M/D/Y) and compact YYYYMMDD
# always return UTC ISO string or None
```

### Explanation

- **Before**: millisecond epochs are treated as seconds → year 53000. US-style dates fail `fromisoformat`.
- **After**: magnitude check + a couple of extra patterns recover far more `signup_at` cells.

**Example input**  
`"signup_ts": 1609459200000` (millis)  
or `"signup_date": "01/01/2021 00:00"`

**Your behavior**  
Millis → year ~53000. US date fails → None.

**Gold behavior**  
Detects magnitude, parses both ISO and US forms, returns UTC ISO string.

**Why it matters**  
`signup_at` is the weakest column (80% correct, 192k missed).

**What to change**  
Add magnitude check for epoch, plus common date patterns (US `M/D/Y`, compact `YYYYMMDD`).

---

## 5. Emails with display names

### Your current code (before)

```python
record.get("email").strip().lower() if ... and record.get("email").count('@') == 1 else None
```

### Proposed change (after)

```python
# strip mailto:, then EMAIL_RE.search, lower the match
```

### Explanation

- **Before**: display-name forms (`Alice <alice@example.com>`) or `mailto:` prefixes produce invalid or rejected values.
- **After**: a simple search extracts the real address.

**Example input**  
`"email": "Alice <alice@example.com>"`  
or `"mailto:alice@example.com"`

**Your behavior**  
May keep a non-address string or drop the cell.

**Gold behavior**  
Extracts and lower-cases the clean address.

**Why it matters**  
“Emails with display names” is 4% of the stream; recovery only 72%.

**What to change**  
Use a simple email regex that searches inside the string.

---

## 6. Plan aliases + numbers as strings

### Your current code (before)

```python
plan = record.get('plan').strip().lower() if ... else None
# then only if plan in ['pro','free','team','enterprise']

seats = int(seats)          # fails on "1,234"
mrr_usd = round(float(mrr),2)  # fails on "$99.50"
```

### Proposed change (after)

```python
# plan: take first alphabetic token
# seats / mrr: strip $, commas, then Decimal / int
```

### Explanation

- **Before**: `"Pro Plan"` becomes `"pro plan"` → not in allow-list. Comma-formatted or currency values fail conversion.
- **After**: token extraction + currency stripping recovers the cells.

**Example input**  
`"plan": "Pro Plan"`, `"seats": "1,234"`, `"mrr": "$99.50"`

**Your behavior**  
Plan → None, seats/mrr → None.

**Gold behavior**  
`"pro"`, `1234`, `"99.50"`.

**Why it matters**  
Plan aliases (6%) and numbers-as-strings (5%) are visible recovery gaps.

**What to change**  
Take the first alphabetic token for plan. Strip currency symbols and thousands separators before converting numbers.

---

## 7. Customer ID strictness

### Your current code (before)

```python
if (customer_id.startswith('C-') and len(customer_id) == 9 and customer_id[2:].isdigit()):
    pass
else:
    customer_id = None
```

### Proposed change (after)

```python
# upper, strip spaces, accept optional C- prefix, keep any plausible id
```

### Explanation

- **Before**: any deviation from the exact 9-character form drops the whole row.
- **After**: light cleaning keeps more recoverable keys.

**Example input**  
`"customer_id": "C-0000001 "` or `1234567` or `"c-0000001"`

**Your behavior**  
Fails the exact check → None → drop.

**Gold behavior**  
Cleans and keeps the id.

**Why it matters**  
`customer_id` still has 129k misses from over-strict validation.

**What to change**  
Upper-case, strip whitespace, accept the `C-` prefix optionally, and keep any plausible id.

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
