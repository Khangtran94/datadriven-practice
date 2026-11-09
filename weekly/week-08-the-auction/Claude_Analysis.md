# Week 8: The Auction: `dag.sql` vs `gold_submit.sql`

**Result [measured]:** score 0.8416, rank #3 of 8, +120 points. Rows built 157,679 of 170,216, so 12,537 rows were never built. 9,254 rows matched no record, costing 18,508 points. 5 statements.

Evidence tags: `[measured]` from the README, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data, `[untested]`.

**How the tests were run [estimate].**
- Synthetic raw tables generated from the README conditions, 3 seeds (5,956 impressions in total).
- 30 nights with a 3-day landing window and incremental merge.
- Scored against the generator's own answer key. The gold file is not the reference, because it has blind spots of its own (see the last section).
- Everything ran in SQLite with small shims for `regexp_like`, `lpad`, `TZ_CONVERT` and `::timestamptz`.
- The numbers show direction and size, not the real score. The platform's engine is unknown, so every fix below is `[untested]` there.

## Impact ranking

| # | Area | Measured loss | Synthetic gain, one fix alone |
|---|---|---|---|
| 1 | Impression ids with `=`, base64url or `%2B/%2F` | 12,537 rows never built; `clicked` wrong 7,192 | +320 rows built, +557 `clicked`, +457 `billed_micros` |
| 2 | Slot names `ML2`, `mainline-2`, `bt3` | `slot` missed 22,626 | +792 `slot` |
| 3 | Prices as `0.85` or whole currency units | `billed_micros` wrong 12,859 | +237 `billed_micros` |
| 4 | No date window | 9,254 rows matched no record | -195 stray rows |
| 5 | ISO and California-offset verdict times | `billed_micros` wrong | +23 `billed_micros` |
| 6 | Verdicts after the account's month closed | `billed_micros` wrong | +27 together with #5 |

All six together, against the answer key [estimate]:

| Column | Your `dag.sql` | With all six | `gold_submit.sql` |
|---|---|---|---|
| Rows built (of 5,956) | 5,831 | 5,956 | 5,956 |
| Stray rows | 195 | 0 | 0 |
| `slot` correct | 4,844 | 5,956 | 5,956 |
| `clicked` correct | 5,398 | 5,955 | 5,823 |
| `billed_micros` correct | 5,115 | 5,955 | 5,781 |

`customer_id`, `served_at` and `served_date` were already 100% correct for built rows.

## 1. Impression ids: only plain 22-character base64 is accepted

- **Your code** (`dag.sql` 161): `CASE WHEN length(impression_id) = 22 AND regexp_like(impression_id, '^[A-Za-z0-9+/]{22}$') THEN impression_id ELSE NULL END AS impression_id,`
- **Gold code** (`gold_submit.sql` 471): strips quotes and the BOM, decodes `%2B` and `%2F`, removes trailing `=`.
- **Example input:** serve id `AbC...xyz==` (older build keeps the padding) and click id `Ab-C_...` (base64url) for the same impression.
- **Your behavior:** the padded serve gets a NULL id and is dropped, so the row is never built. The click with `-` or `_` gets a NULL id and is dropped, so `clicked` and `billed_micros` are wrong.
- **Why it matters [measured]:** README "Ids with = padding" is 5.0% of tables, recovered 0%. "Click ids encoded for a URL" is 45%, recovered 65%. Unbuilt rows are 7.4% of 170,216 and `customer_id` missed is exactly 12,537.
- **Not fully explained [inferred]:** 7.4% is more than the 5.0% padding share, so something else also drops rows.
- **Before:** `dag.sql` 161 as above, plus line 195: `FROM replace_null),`
- **After:**

```sql
    CASE WHEN regexp_like(iid, '^[A-Za-z0-9+/]{22}$') THEN iid ELSE NULL END AS impression_id,
    ...
    loaded_at
FROM (SELECT *, REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(RTRIM(impression_id, '='), '%2B', '+'), '%2b', '+'), '%2F', '/'), '%2f', '/'), '-', '+'), '_', '/') AS iid
      FROM replace_null) AS replace_null),
```

- **How it works:** every spelling of an id becomes one canonical form (standard base64, no padding) before the check, so a serve and its click meet on the same key.
- **Proof [estimate]:** unbuilt 320 -> 0, `clicked` +557, `billed_micros` +457.

## 2. Old slot names

- **Your code** (185-191): lists `top-1`, `top1`, `top 01` and so on, but not `ML2`, `mainline-2` or `bt3`.
- **Example input:** `ML2` should be `top-2`; `btm-2` should be `bottom-2`.
- **Why it matters [measured]:** `slot` missed 22,626 - 12,537 = 10,089 rows (5.9%). README "Slots named the old way" is 14% of tables, recovered 82%.
- **After:** two lines before the existing lists:

```sql
    WHEN regexp_like(lower(detail), '^(top|mainline|ml|above)[-_ ]?0?[1-4]$') THEN 'top-' || substr(detail, -1)
    WHEN regexp_like(lower(detail), '^(bottom|bt|btm|bot|below|b)[-_ ]?0?[1-3]$') THEN 'bottom-' || substr(detail, -1)
```

- **How it works:** one pattern per side of the page, so a new spelling does not need a new list entry.
- **Proof [estimate]:** `slot` 4,844 -> 5,636 correct.
- **Not covered [untested]:** the README's example `B1` is in the pattern but was not generated. Gold does not map it either.

## 3. Prices in units of money

- **Your code** (192): `WHEN detail <> '' AND regexp_like(detail, '^[+-]?[0-9]+(\.[0-9]+)?$') THEN CAST(CAST(detail AS INTEGER) AS VARCHAR)`
- **Example input:** `0.85` (legacy click path) and `45` (a yen account).
- **Your behavior:** `0.85` is cast to integer 0, so the click bills 0. `45` stays 45 micros, a millionth of the real price.
- **Why it matters [measured]:** `billed_micros` wrong 12,859. README "Prices in units of money" is 30% of tables, recovered 75%.
- **After:**

```sql
    WHEN regexp_like(detail, '^[0-9]+\.[0-9]+$') THEN CAST(CAST(ROUND(CAST(detail AS DOUBLE) * 1000000) AS INTEGER) AS VARCHAR)
    WHEN regexp_like(detail, '^[0-9]+$') AND CAST(detail AS INTEGER) >= 10000 AND CAST(detail AS INTEGER) % 10000 = 0 THEN detail
    WHEN regexp_like(detail, '^[0-9]+$') THEN CAST(CAST(detail AS INTEGER) * 1000000 AS VARCHAR)
```

- **How it works:** decimals are multiplied by a million. A whole number is already micros only if it is at least 10,000 and a multiple of 10,000; otherwise it is whole currency units.
- **Caveat [inferred]:** the 10,000 rule is copied from gold's heuristic. A real price between 10,000 and 99,999 whole units would be misread.
- **Proof [estimate]:** `billed_micros` +237.

## 4. No date window

- **Your code** (335-337): the final `SELECT` ends at `LEFT JOIN invalid_flag AS f ON f.impression_id = sa.impression_id;` with no `WHERE`.
- **Gold code:** keeps only serves from 2026-10-09 00:00Z up to 2026-11-08 00:00Z.
- **Example input:** an ad served on 2026-10-08, still in the first night's log.
- **Why it matters:** the README asks for ads shown 2026-10-09 to 2026-11-07, and 9,254 rows matched no record [measured]. The synthetic stray rows were all out-of-window serves [estimate], so the real ones are read as the same cause [inferred].
- **After:**

```sql
LEFT JOIN invalid_flag AS f ON f.impression_id = sa.impression_id
WHERE sa.served_at >= '2026-10-09T00:00:00Z' AND sa.served_at < '2026-11-08T00:00:00Z';
```

- **Proof [estimate]:** stray rows 195 -> 0.

## 5 and 6. Verdict times and the month close

- **Your code** (172-180, 312-325): `event_time` only reads 10-, 13- or 16-digit numbers, so fraud-filter verdicts (ISO text) get a NULL time. `invalid_flag` fires only when the invalid row's time equals the latest time of any event, so those verdicts never fire.
- **Example input:** `2026-10-24T09:41:24-07:00` (older build, California time) or `...Z`.
- **Why it matters [measured]:** README "Times in 3 other forms" is 18% of tables, recovered 77%. "Credited the month after" is a click ruled out after its month closed on the account's calendar; that verdict must not zero the bill.
- **After, part 1** (event time), added before `END AS event_time,`:

```sql
    WHEN regexp_like(event_time, '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}') THEN strftime('%Y-%m-%dT%H:%M:%SZ', event_time)
```

- **After, part 2** (replace `last_time` and `invalid_flag`):

```sql
first_click AS (SELECT impression_id, event_time AS click_time FROM click_ranked WHERE rn = 1),
month_close AS (
    SELECT sa.impression_id, fc.click_time,
           REPLACE(REPLACE(fc.click_time, 'T', ' '), 'Z', '') AS click_txt,
           TZ_CONVERT(DATE(DATE(TZ_CONVERT(fc.click_time, 'UTC', sa.tz)), 'start of month', '+1 month') || ' 00:00:00', sa.tz, 'UTC') AS close_txt
    FROM serve_account AS sa INNER JOIN first_click AS fc ON fc.impression_id = sa.impression_id),
verdict_ranked AS (
    SELECT e.impression_id, e.event_category,
           ROW_NUMBER() OVER (PARTITION BY e.impression_id ORDER BY e.event_time DESC, e.event_key) AS rn
    FROM ev AS e INNER JOIN month_close AS m ON m.impression_id = e.impression_id
    WHERE e.event_category IN ('invalid', 'valid')
      AND REPLACE(REPLACE(e.event_time, 'T', ' '), 'Z', '') < m.close_txt),
invalid_flag AS (SELECT impression_id FROM verdict_ranked WHERE rn = 1 AND event_category = 'invalid')
```

  This also needs `event_time` added to the `click_ranked` select and `COALESCE(a.time_zone, 'UTC') AS tz` added to `serve_account`.
- **How it works:** every verdict gets a real time. Only verdicts before the account's local month end count, and the latest of those decides.
- **Proof [estimate]:** `billed_micros` +23 for part 1 alone, +27 with part 2. Part 2 alone does nothing.

## Not explained
- **`served_at` and `served_date`:** 28,557 missed [measured], 16,020 beyond the unbuilt rows. The synthetic data produced no NULL `served_at` in built rows, so this was not reproduced.
- **Suspects [inferred]:** a serve time shape the README does not list; and line 249 `ORDER BY event_time, event_key`, which puts a NULL-time duplicate first.
- **Cheap guard [untested]:** add `AND event_time IS NOT NULL` to the serve rows in `serve_ranked`.

## Handled correctly in your code
Row dedup by event key, history kept so late verdicts still apply, account versions as of the serve time with first-version fallback, DST-aware `served_date` (100% correct in the test), customer id dashes and leading zeros, and the 2-click cap.

## Gold's blind spots (why the answer key was used)
- **base64url click ids:** gold never turns `-` or `_` back into `+` or `/`, so those clicks do not join (`clicked` 5,823 of 5,956).
- **`IVT`:** missing from gold's invalid list (line 410) although the README names it, so gold under-zeroes those bills (`billed_micros` 5,781).
- **`reinstated` and `B1`:** neither file maps them [inferred]; not generated, so untested.

## Recommended pattern
Make every key-like column canonical in the first transform step, then filter to the requested window last. Most of the loss is one strict shape check on a column the README lists with several forms.
