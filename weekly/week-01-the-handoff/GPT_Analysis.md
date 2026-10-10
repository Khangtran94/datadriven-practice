# Week 1: The Handoff — `handler.py` vs `gold_submit.py`

## Result summary

| Metric | Result |
|---|---:|
| Score | 0.5159 |
| Rank | #8 of 11 |
| Records recovered | 821,962 / 951,089 |
| Work per record | 1.2× median |
| Duplicate rows | 854,938 |
| Points lost to duplicate rows | 1,709,876 |

Source: `README.md`, lines 9–21.

**Main conclusion:** The clearest high-impact defect is output lifecycle management. My `process()` emits each accepted row, while `finalize()` emits the accumulated customer rows again. The reference emits rows from `process()` and returns an empty list from `finalize()`.

Other important gaps are strict JSON parsing, limited field aliases, incomplete timestamp parsing, and weaker field normalization.

## Impact ranking

| Priority | Gap | Evidence | Expected impact |
|---:|---|---|---|
| 1 | Duplicate output from `process()` and `finalize()` | README reports 854,938 duplicate rows and a 1,709,876-point penalty | Critical; directly aligned with a measured score penalty |
| 2 | Strict JSON parsing | Broken JSON structure: 6% of stream, only 12% recovered | High; whole records can be discarded |
| 3 | Missing field aliases and nested-field support | Nesting/flattening: 10% of stream, 51% recovered; localized keys: 5%, 2% recovered | High; required fields may appear absent |
| 4 | Incomplete timestamp normalization | Epoch seconds/milliseconds: 8%, 62% recovered; mixed dates: 8%, 75% recovered | High; `signup_at` has 192,378 missed and 585 wrong values |
| 5 | Limited email, plan, and numeric cleanup | Display-name emails: 4%, 72% recovered; plan aliases: 6%, 69%; numbers as strings: 5%, 72% | Medium to high; values may become null or incorrect |
| 6 | Narrow customer-ID lookup and broad exception handling | Only `customer_id` is read; all exceptions are silently swallowed | Medium; aliases are missed and failures are hard to diagnose |
| 7 | Mutable class-level state | `customers` is defined at class scope | Robustness risk; state may leak between instances |

The condition-level figures come from the README. The ranking of implementation changes is an engineering assessment, not a measured decomposition of the score.

---

## 1. Output lifecycle: emitting customers twice

### My implementation

`handler.py`, lines 62–69:

```python
Handler.customers[customer_id] = row
return [row]

def finalize(self):
    return list(Handler.customers.values())
```

### Reference implementation

`gold_submit.py`, lines 254–270:

```python
class Handler:
    def process(self, raw):
        try:
            rec = parse_json_line(raw)
            if not rec:
                return []
            row = clean_record(rec)
            return [row] if row else []
        except Exception:
            return []

    def finalize(self):
        return []
```

### Example

Two input records describe the same customer:

```json
{"customer_id":"C-1234567","email":"first@example.com","plan":"pro"}
{"customer_id":"C-1234567","email":"latest@example.com","plan":"team"}
```

My handler returns a row from `process()` for each valid record. It also overwrites the customer's entry in `Handler.customers`. At finalization, it returns the latest stored row again.

The resulting output can contain the first version, the second version, and another copy of the latest version from `finalize()`.

The reference emits each valid cleaned input row through `process()` and emits nothing at finalization.

### Why it matters

The README reports **854,938 rows that were a second row for a key already emitted**, costing **1,709,876 points**. This is the strongest direct match between a code defect and an explicitly measured scoring penalty in this week.

The aggregate result does not prove that every duplicate came from these exact lines, but the implementation clearly creates this risk.

### What to change

For this task's streaming contract, follow the reference lifecycle:

```python
def process(self, raw):
    # Parse and normalize one input record.
    # Return only the rows intended for this record.
    return []

def finalize(self):
    # Emit deferred/reconciled rows only if the task requires them.
    return []
```

Do not combine immediate row emission with a second emission of the same stored rows.

If a future task requires one final row per key, choose one consistent strategy: hold and reconcile records until `finalize()`, or emit incrementally according to the task's rules. Do not do both.

---

## 2. JSON parsing: strict parsing loses recoverable records

### My implementation

`handler.py`, lines 6–8 and 65–66:

```python
def process(self, raw):
    try:
        record = json.loads(raw)
        # ...
    except:
        return []
```

### Reference implementation

`gold_submit.py`, lines 28–68, in `parse_json_line()`:

```python
def parse_json_line(raw):
    if raw is None:
        return None
    if isinstance(raw, dict):
        return raw
    # Normalize the input representation and remove a BOM.
    # Try standard JSON parsing, including JSON encoded as a string.
    # If needed, attempt recovery from a JSON object span.
```

The reference also removes trailing commas before retrying JSON parsing.

### Example

A line contains a trailing comma:

```json
{"customer_id":"C-1234567","plan":"pro",}
```

My handler's `json.loads()` raises an exception, so the entire record is dropped. The reference parser can remove the trailing comma and attempt to recover the object.

The reference also accepts a dictionary directly and can handle some JSON-encoded strings or wrapped object spans. It is not a universal repair engine: irrecoverably truncated or ambiguous data may still be rejected.

### Why it matters

The README says broken JSON structure affects 6% of the stream, with only 12% recovered. This is a major opportunity to improve record recovery.

### What to change

Create a dedicated parsing function with a clear contract:

```python
def parse_record(raw):
    # Handle supported input types.
    # Try standard JSON first.
    # Apply only deliberate, safe recovery rules.
    # Return a dictionary or None.
    ...
```

Keep parsing separate from field normalization so recovery behavior can be tested independently.

---

## 3. Field discovery: aliases and nesting are missing

### My implementation

`handler.py`, lines 11, 27, 40, 42, and 48:

```python
customer_id = record.get("customer_id")
signup_ts = record.get("signup_ts")
plan = record.get("plan")
seats = record.get("seats")
mrr = record.get("mrr")
```

### Reference implementation

`gold_submit.py`, in `clean_record()` (around lines 225–252):

```python
cid = clean_customer_id(
    first(
        rec.get("customer_id"),
        rec.get("customerId"),
        rec.get("id"),
    )
)

# Other fields use similar fallback logic:
# signup_ts / signup_at / signup_date / created_at
# plan / plan_tier / tier
# seats / seat_count
# mrr / mrr_usd
```

The reference uses `first()` to select the first nonblank candidate.

### Example

```json
{
  "customerId": "C-1234567",
  "signup_date": "2024-01-02",
  "plan_tier": "pro",
  "seat_count": "10",
  "mrr_usd": "$125.00"
}
```

My handler only looks for `customer_id`. Since that field is absent, it returns `[]` before processing any other fields. The reference can identify the customer through `customerId` and find the other values through their aliases.

### Why it matters

The README identifies nesting/flattening as 10% of the stream, with 51% recovered, and localized key names as 5%, with 2% recovered.

Alias handling is directly demonstrated in the reference. Full nested-object traversal and translation of every localized key are not implemented explicitly in `clean_record()`, so these conditions may need additional, task-specific handling beyond copying the reference's aliases.

### What to change

Centralize aliases in one place:

```python
FIELD_ALIASES = {
    "customer_id": ["customer_id", "customerId", "id"],
    "signup_at": ["signup_ts", "signup_at", "signup_date", "created_at"],
    "plan": ["plan", "plan_tier", "tier"],
    "seats": ["seats", "seat_count"],
    "mrr_usd": ["mrr", "mrr_usd"],
}
```

Implement `first()` and a field-lookup helper. If samples show fields moving into nested objects, add controlled flattening or nested-path lookup as a separate step. For localized field names, use an explicit mapping supported by the brief and samples rather than guessing translations.

---

## 4. Timestamp normalization: seconds, milliseconds, and mixed formats

### My implementation

`handler.py`, lines 27–38:

```python
signup_ts = record.get("signup_ts")

if isinstance(signup_ts, (int, float)):
    signup_at = datetime.fromtimestamp(
        signup_ts, tz=timezone.utc
    ).strftime("%Y-%m-%dT%H:%M:%SZ")
elif isinstance(signup_ts, str):
    try:
        dt = datetime.fromisoformat(
            signup_ts.replace("Z", "+00:00")
        )
        signup_at = dt.astimezone(timezone.utc).strftime(
            "%Y-%m-%dT%H:%M:%SZ"
        )
    except ValueError:
        signup_at = None
else:
    signup_at = None
```

### Reference implementation

`gold_submit.py`, lines 129–170, in `clean_signup()`:

```python
if isinstance(v, (int, float)):
    n = float(v)
    if n <= 0:
        return None

    if n >= 1e14:
        n /= 1e6
    elif n >= 1e11:
        n /= 1e3

    # Convert the normalized timestamp to UTC.
```

The reference also supports numeric timestamps encoded as strings, ISO-style dates, US-style dates, compact `YYYYMMDD`, and explicit UTC offsets.

### Example

```json
{"customer_id":"C-1234567","signup_ts":1720000000000}
```

My handler passes the numeric value directly to `datetime.fromtimestamp()` as seconds. A millisecond timestamp can therefore cause an out-of-range error, which the outer exception handler turns into a dropped record.

The reference recognizes a millisecond-scale value and divides it by 1,000 before conversion.

Another example:

```json
{"customer_id":"C-1234567","signup_date":"07/02/2024"}
```

My handler does not support this US-style date format. The reference parses it using the stated month-first rule for ambiguous dates.

### Why it matters

The README reports epoch seconds/milliseconds in 8% of the stream, with 62% recovered, and mixed date formats in another 8%, with 75% recovered. The `signup_at` column has 192,378 missed values and 585 wrong values.

### What to change

Use one timestamp normalizer that:
1. Rejects blank and unsupported values.
2. Detects supported numeric units before conversion.
3. Parses supported string formats deliberately.
4. Applies explicit timezone rules.
5. Produces a single UTC representation.
6. Returns `None` when a value cannot be interpreted safely.

Do not assume every integer timestamp is in seconds.

---

## 5. Field normalization: email, plan, and numeric values

### My implementation

`handler.py`, lines 40–52 and 54–60:

```python
plan = (
    record.get("plan").strip().lower()
    if isinstance(record.get("plan"), str)
    else None
)

seats = int(seats) if seats is not None else None
mrr_usd = round(float(mrr), 2) if mrr is not None else None
```

The email expression on line 56 trims and lowercases strings containing exactly one `@`.

### Reference implementation

The reference separates each field's rules:

- `clean_email()`, lines 80–90, removes a `mailto:` prefix and extracts an email address from surrounding display text.
- `clean_plan()`, lines 173–183, normalizes whitespace and recognizes plan tokens.
- `clean_seats()`, lines 186–206, handles integer-valued floats and numeric strings with commas or extra text.
- `clean_mrr()`, lines 209 onward, uses `Decimal`, removes currency symbols and separators, rejects non-finite values, and formats monetary values to two decimal places.

### Examples

**Email with a display name**

```json
{"customer_id":"C-1234567","email":"Jane Doe <Jane.Doe@example.com>"}
```

My code checks only that there is exactly one `@`; it can return the entire display string as the email. The reference extracts `Jane.Doe@example.com`.

**Plan with extra text**

```json
{"customer_id":"C-1234567","plan":"Pro - legacy"}
```

My code normalizes the entire string to `pro - legacy`, which is not in the allowed list, and returns `None`. The reference checks the leading plan token and can normalize it to `pro`.

**Money represented as text**

```json
{"customer_id":"C-1234567","mrr":"$1,250.00"}
```

My code's `float()` cannot parse the dollar sign and comma, so it returns `None`. The reference strips these supported formatting characters and returns `"1250.00"`.

### Why it matters

The README reports:
- Display-name emails: 4% of the stream, 72% recovered.
- Plan aliases: 6%, 69% recovered.
- Numbers as strings: 5%, 72% recovered.

The column-level results also show 20,857 wrong email values, alongside missed values across every output field.

### What to change

Keep a dedicated cleaner per field rather than putting all normalization inline in `process()`:

```python
def clean_email(value):
    ...

def clean_plan(value):
    ...

def clean_seats(value):
    ...

def clean_mrr(value):
    ...
```

Use the output schema and brief to decide which formats are valid. Avoid extracting arbitrary numbers from text unless that recovery rule is justified by the input contract.

---

## 6. Customer-ID lookup and exception handling

### My implementation

`handler.py`, lines 11–25:

```python
customer_id = record.get("customer_id")

if isinstance(customer_id, str):
    customer_id = customer_id.strip().upper()
    if (
        customer_id.startswith("C-")
        and len(customer_id) == 9
        and customer_id[2:].isdigit()
    ):
        pass
    else:
        customer_id = None
else:
    customer_id = None

if customer_id is None:
    return []
```

The entire `process()` function also uses a broad `except:` clause.

### Reference implementation

`gold_submit.py`, lines 80–89:

```python
def clean_customer_id(v):
    if _is_blank(v) or isinstance(v, (dict, list, bool)):
        return None
    if isinstance(v, (int, float)):
        if isinstance(v, float) and not v.is_integer():
            return None
        v = str(int(v))
    s = str(v).strip().upper()
    s = re.sub(r"\s+", "", s)
    return s or None
```

The reference also looks up `customerId` and `id` aliases.

### Example

```json
{"id":"C-1234567","email":"a@example.com"}
```

My handler drops the record because `customer_id` is absent. The reference accepts the alias.

A broad exception handler also hides the distinction between malformed input, an unsupported timestamp, and a programming error.

### What to change

- Support ID aliases required by the brief.
- Normalize whitespace consistently.
- Keep validation rules aligned with the actual contract; do not assume alternate representations are valid without evidence.
- Catch expected exceptions at the smallest sensible scope.
- Add diagnostic counters when the execution environment permits them, while keeping standard output compliant with the competition contract.

---

## 7. Class-level mutable state

### My implementation

`handler.py`, line 5:

```python
class Handler:
    customers = {}
```

### Why it matters

This dictionary is shared by instances of `Handler`, rather than initialized separately for each instance. If the runtime creates multiple handler instances in the same Python process, one instance can see state left by another. It also retains every customer's latest row even though `process()` already emits rows.

The reference does not need this state because it returns each cleaned row directly and has an empty `finalize()`.

### What to change

For this task, remove `customers` when using the reference's streaming approach. If a future task requires buffered reconciliation, initialize the buffer in `__init__()` and clear or finalize it according to the runtime contract.

---

## Recommended implementation pattern

For this week, the best first step is not a complete rewrite. Preserve the working parts, but separate parsing, field lookup, normalization, and emission. Most importantly, fix the output lifecycle before tuning field-level parsing.

```python
class Handler:
    def process(self, raw):
        record = parse_json_line(raw)
        if record is None:
            return []

        row = clean_record(record)
        return [row] if row is not None else []

    def finalize(self):
        return []
```

Recommended helper responsibilities:

```python
def parse_json_line(raw):
    # Parse standard JSON and apply safe recovery rules.
    ...

def first(*values):
    # Return the first nonblank candidate.
    ...

def clean_record(record):
    # Resolve aliases and build the output schema.
    ...

def clean_customer_id(value):
    ...

def clean_email(value):
    ...

def clean_signup(value):
    ...

def clean_plan(value):
    ...

def clean_seats(value):
    ...

def clean_mrr(value):
    ...
```

## Suggested order of work

1. **Fix duplicate emission.** Ensure a customer row is not returned both by `process()` and `finalize()`.
2. **Add parsing tests.** Include valid JSON, trailing commas, JSON-encoded strings, and malformed or truncated lines.
3. **Add alias-based field lookup.** Cover known aliases before attempting broader flattening.
4. **Improve timestamp parsing.** Test seconds, milliseconds, numeric strings, ISO timestamps, timezone offsets, and supported date-only formats.
5. **Improve field normalization.** Test display-name emails, plan suffixes, comma-separated numbers, and currency-formatted MRR.
6. **Test state isolation.** Ensure a new handler instance cannot inherit buffered state from another instance.
7. **Compare exact output rows and counts.** Validate both values and row counts, not only whether the output looks plausible.

## Final assessment

My Week 1 solution handles ordinary JSON objects, normalizes common customer IDs and strings, and converts straightforward timestamps and numeric fields. However, it is optimized for clean input and mixes parsing, validation, transformation, state, and output emission in one method.

The reference is more resilient because it treats transformations as explicit normalization functions and matches the expected streaming lifecycle. The first improvement should be the duplicate-emission fix because the README quantifies its penalty. After that, focus on recoverable parsing and the input variants identified by the competition brief.

The goal is not to copy every line of the reference. It is to build small, testable transformations that cover the input contract while guaranteeing correct row identity and emission behavior.
