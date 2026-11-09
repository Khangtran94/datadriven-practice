# Week 8 – The Auction: dag.sql vs gold_submit.sql

**Score:** 0.8416 (#3 of 8)  
**Rows:** 157,679 of 170,216 (9,254 matched no record)

## Impact ranking

| Rank | Issue | Approx. cost | Status in dag.sql |
|------|-------|--------------|-------------------|
| 1 | Impression-ID padding / URL-encoding / base64url not stripped | High (5 % of IDs) | Partial (exact 22-char only) |
| 2 | Incomplete timestamp normalization (3 other forms) | High | Only pure digit µs/ms/s |
| 3 | Slot vocabulary (mainline / ML / B*) missing | Medium | Only top-/bottom- variants |
| 4 | Price unit conversion (decimal / yen) | Medium | Integer micros only |
| 5 | Month-close verdict window missing | Medium | Latest event only, no cutoff |
| 6 | Account as-of + zone offsets incomplete | Low-Medium | Simple LEAD interval, no offset table |
| 7 | adtest / partner filter missing | Low | None |

### 1. Impression-ID normalization (padding, URL, base64url)

**Your current code (before)** — event_version, around the normalized CTE:
```sql
CASE WHEN length(impression_id) = 22 AND regexp_like(impression_id, '^[A-Za-z0-9+/]{22}$')
     THEN impression_id ELSE NULL END AS impression_id
```

**Proposed change (after)**:
```sql
-- strip trailing = padding, convert base64url, percent-decode, then validate
REPLACE(REPLACE(REPLACE(
  CASE WHEN right(trim(impression_id), 1) = '=' THEN rtrim(trim(impression_id), '=')
       ELSE trim(impression_id) END,
  '-', '+'), '_', '/'), '%2B', '+')  -- plus further %2F etc.
-- then apply length/charset check or keep original if already clean
```

**Explanation:** Older serving builds keep the two `=` padding characters; click servers emit base64url or `%2B`/`%2F`. Exact 22-char standard-base64 match drops ~5 % of impressions and their clicks. Gold strips padding and normalizes the alphabet before using the ID as the join key.

**Example:** serve `A3ov7PHu5IgfPo0Zyfyqzw==` vs click `A3ov7PHu5IgfPo0Zyfyqzw` or with URL encoding → user drops both, gold matches.

### 2. Timestamp forms

**Your current code (before)**:
```sql
CASE
  WHEN regexp_like(event_time, '^[0-9]{16}$')
    THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE)/1000000.0, 'unixepoch')
  WHEN regexp_like(event_time, '^[0-9]{13}$')
    THEN strftime(..., /1000.0, 'unixepoch')
  ...
END AS event_time
```

**Proposed change (after)** — expand the CASE (or a reusable parser CTE) to also handle packed YYYYMMDDHHMMSS, ISO with T/Z/+HH:MM, scientific notation, trailing UTC/GMT. Convert everything to numeric epoch for ordering and ISO seconds for served_at.

**Explanation:** 18 % of times arrive in non-digit forms. Ranking on raw text or only pure-digit paths picks the wrong first click or last verdict.

### 3. Slot names (legacy mainline)

**Your current code (before)**:
```sql
WHEN lower(detail) IN ('top-1','top1',...) THEN 'top-1'
...
ELSE NULL
```

**Proposed change (after)**:
```sql
WHEN lower(detail) LIKE 'mainline-%' OR lower(detail) LIKE 'ml%' OR lower(detail) LIKE 'above%'
  THEN 'top-' || regexp_substr(detail, '[1-4]')
WHEN lower(detail) LIKE 'b1' OR lower(detail) LIKE 'btm%'
  THEN 'bottom-' || ...
```

**Explanation:** Older builds emit ML2, mainline-2, B1. Those become NULL; gold maps them to canonical top-N / bottom-N.

### 4. Price units

**Your current code (before)**:
```sql
SUM(CASE WHEN regexp_like(raw_detail, '^-?[0-9]+$')
         THEN CAST(raw_detail AS BIGINT) ELSE 0 END)
```

**Proposed change (after)**:
```sql
CASE
  WHEN raw_detail ~ '^[0-9]+\.[0-9]+$' THEN ROUND(CAST(raw_detail AS NUMERIC) * 1000000)
  WHEN CAST(raw_detail AS BIGINT) < 10000 THEN CAST(raw_detail AS BIGINT) * 1000000
  ELSE CAST(raw_detail AS BIGINT)
END
```

**Explanation:** Legacy path logs 0.85 or 45. Reading as micros under-bills by 1e6. Gold converts before summing first two clicks.

### 5. Month-close verdict window

**Your current code (before)**:
```sql
invalid_flag AS (
  SELECT DISTINCT e.impression_id
  FROM ev e JOIN last_time l ON ...
  WHERE e.event_category = 'invalid'
)
```

**Proposed change (after)**: for each of the first two clicks compute account-local month-end epoch; take latest verdict whose epoch < that month-end; if invalid then that click contributes 0.

**Explanation:** Post-close verdicts do not affect the closed invoice. User's any-time last event incorrectly zeros some billed clicks.

### Recommended pattern skeleton

```sql
/* dag.yml — incremental history on both streams */
-- task: ad_events_history / accounts_history
--   defensive cleaning + epoch extraction + merge

-- task: event_norm
--   ID normalizer, kind map, slot map, price-to-micros, epoch

-- task: ad_impressions
WITH keep AS ( /* serves with valid ID, not adtest, not partner, in window */ ),
clicks AS ( /* first 2 priced clicks */ ),
verd AS ( /* latest verdict before account month-end */ )
SELECT ... billed = sum(case when verd.invalid then 0 else micros end)
```

The skeleton recovered the majority of rows. Remaining gaps are the edge-case normalizations above.
