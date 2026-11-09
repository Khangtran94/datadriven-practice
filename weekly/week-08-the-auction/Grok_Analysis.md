# Week 8 – The Auction: dag.sql vs gold_submit.sql

**Your score:** 0.8416 (#3 of 8, top 38%)  
**Your file:** `dag.sql`  
**Top-1 file:** `gold_submit.sql`  
**Rows built:** 157,679 of 170,216  
**Points:** +120  

This note compares your submission to the top solution. Sections are ordered by **impact** (biggest score gaps first). Each section uses a vertical layout so you can read example → your behavior → gold behavior without scanning a wide table.

9,254 rows matched no record (cost 18,508 points). The largest column gaps are `served_at` / `served_date` (only 83 % correct) and `billed_micros` (85 %).

---

## Impact ranking (fix these first)

| Priority | Area | Why it moves the score |
|----------|------|------------------------|
| 1 | Impression-id normalisation (padding, URL encoding) | Clicks fail to join serves; “Ids with = padding” and “Click ids encoded for a URL” are marked “no”. |
| 2 | Multi-format timestamps | First-click / last-verdict ranking and served_at/served_date break on non-digit forms. |
| 3 | Price units + billing rules | billed_micros wrong when detail is 0.85, yen, or when verdicts/credits apply. |
| 4 | Slot names (legacy) | slot column misses ML2 / mainline-2 / B1. |
| 5 | As-of timezone + DST + incremental watermark | served_date wrong near midnight or after TZ moves; late Asia files dropped. |

---

## 1. Impression-id normalisation

### Your current code (before)

```sql
CASE WHEN length(impression_id) = 22 AND regexp_like(impression_id, '^[A-Za-z0-9+/]{22}$') 
     THEN impression_id ELSE NULL END AS impression_id
```

### Proposed change (after)

Strip trailing `=` padding, decode base64url (`-`→`+`, `_`→`/`) and percent-encoding (`%2B`→`+`, `%2F`→`/`), then keep the canonical 22-character form. Gold does this inside the event_norm task so every click joins its serve.

### Explanation

- **Before:** padded or URL-encoded IDs become NULL or fail to match → missing click settlement.
- **After:** the same bytes produce the same key.

**Example input**  
Serve: `abc...==` ; Click: `abc...` or `abc...%2B...`

**Your behavior**  
No match → impression row with clicked=0 and billed=0 (or dropped).

**Gold behavior**  
Normalised IDs match → click and price applied.

**Why it matters**  
“Ids with = padding on the end” (5 %) and “Click ids encoded for a URL” (45 %) are both marked “no”.

**What to change**  
Add the strip / replace steps before the length/regex check in event_version (or a dedicated norm task).

---

## 2. Multi-format timestamps

### Your current code (before)

```sql
CASE
  WHEN regexp_like(event_time, '^[0-9]{16}$') THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE)/1000000.0, 'unixepoch')
  WHEN regexp_like(event_time, '^[0-9]{13}$') THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE)/1000.0, 'unixepoch')
  WHEN regexp_like(event_time, '^[0-9]{10}$') THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE), 'unixepoch')
END AS event_time
```

### Proposed change (after)

Gold’s epoch parser accepts pure digits (any length 8–19), dotted scientific notation, ISO with T/Z/offsets, slash dates, “UTC”/“GMT” suffixes, and California-style offsets, reducing everything to integer seconds. Ranking then uses that epoch.

### Explanation

- **Before:** ISO, offset, or other writer forms become NULL → wrong first-click / last-verdict and wrong served_at.
- **After:** all forms become comparable epochs.

**Example input**  
event_time = `2026-10-15T18:00:00-07:00` or `1.761e9`

**Your behavior**  
NULL → serve ranked incorrectly or dropped.

**Gold behavior**  
Correct epoch → proper ranking and served_at.

**Why it matters**  
“Times in 3 other forms” (18 %) recovered only 77 % and marked “no”. served_at / served_date are only 83 % correct.

**What to change**  
Replace the three WHEN branches with a comprehensive CASE that mirrors the gold parser (or call a UDF).

---

## 3. Price units and billing rules

### Your current code (before)

```sql
SUM(CASE WHEN regexp_like(raw_detail, '^-?[0-9]+$')
         THEN CAST(raw_detail AS BIGINT) ELSE 0 END) AS billed_micros
...
CASE WHEN f.impression_id IS NOT NULL THEN 0 ELSE COALESCE(c.billed_micros, 0) END
```
(last event is invalid → zero; first two numeric details summed)

### Proposed change (after)

Convert any numeric detail (decimal, comma, yen integer ≥ 10000 that is multiple of 10000, already-micros) to micros. Rank up to two clicks by epoch, then apply the latest valid/invalid verdict that arrived before the account’s month-close epoch. Invalid → 0.

### Explanation

- **Before:** 0.85 stays 0.85 (or becomes 0); a later clearing verdict or post-close credit is ignored.
- **After:** 0.85 → 850000; last pre-close verdict wins; third click is ignored.

**Example input**  
Click detail = `0.85`; later “reinstated” verdict before month close.

**Your behavior**  
billed_micros = 0 or wrong integer.

**Gold behavior**  
billed_micros = 850000.

**Why it matters**  
“Prices in units of money” (30 %), “Flagged, then cleared”, “Credited the month after”, “A third click on 1 ad”. billed_micros is only 85 % correct.

**What to change**  
Add a price-to-micros CASE and a ranked-verdict join limited to month_end.

---

## 4. Legacy slot names

### Your current code (before)

Only maps exact top-1 / top1 / top_1 … and bottom-1 … forms; everything else becomes NULL.

### Proposed change (after)

Gold maps ML2, mainline-2, above-1, B1, btm-1, bot-1, etc. onto top-N / bottom-N.

### Explanation

- **Before:** older serving builds produce NULL slot.
- **After:** canonical top-/bottom- name.

**Why it matters**  
“Slots named the old way” (14 %) marked “no”. slot column is only 87 % correct.

**What to change**  
Expand the CASE list in event_version with the legacy patterns shown in gold.

---

## 5. As-of timezone, DST and incremental watermark

### Your current code (before)

```sql
LEFT JOIN {{ this }} AS x ON x.event_key = d.event_key
WHERE x.event_key IS NULL   -- append-only
...
DATE(TZ_CONVERT(s.served_at, 'UTC', COALESCE(a.time_zone, 'UTC')))::date
```

### Proposed change (after)

Gold stores loaded_epoch and keeps rows where loaded_epoch >= max already seen (late Asia / re-copies). Account versions are intervalled; the zone in force on the serve day is used, and a fixed offset table supplies the DST transition offsets for the month.

### Explanation

- **Before:** late files are dropped; fixed TZ_CONVERT misses DST and east-moves.
- **After:** late rows land; served_date uses the correct offset for that calendar day.

**Why it matters**  
“Asia's file after the run”, “An account that moved east”, “A clock change mid-month”. served_date is only 83 % correct.

**What to change**  
Switch history tasks to a loaded_epoch watermark (or merge on a stable key) and materialise DST-aware offsets.

---

## Recommended pattern (SQL / DAG)

1. History tasks (`ad_events_history`, `accounts_history`): stable key, loaded_epoch watermark, full null-as-text + ID normalisation.
2. Intermediate `event_norm`: comprehensive epoch parser, slot/event maps, price-to-micros, impression-id cleaning.
3. Final `ad_impressions`: as-of account TZ (with DST offsets) → serve date; rank up to 2 clicks; apply last pre-close verdict; emit the scoring columns.

Start with impression-id cleaning and the multi-format epoch parser. Those two changes address the largest row losses and the served_at / served_date gaps.
