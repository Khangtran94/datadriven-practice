# Week 5: The Close: `dag.sql` vs `gold_submit.sql`

**Your score:** 0.0000 · **Rank:** #11 of 13 (top 85%) · **Points:** +0
**Rows built:** 0 of 99,261 · **Run:** crashed at task `fct_payments` · **Work per raw row:** .07x median · **Statements:** 4
**Context:** a card payments company closes its books through 2026-10-12. The DAG must build `fct_payments` (1 row per payment, 8 columns) from 3 raw tables that keep only recent nightly copies, on a nightly schedule, from 2026-09-18 to 2026-10-17.

**Evidence tags:** `[measured]` from the README or platform feedback · `[inferred]` from reading the code · `[estimate]` from my local test on synthetic data · `[not available]` code that is not in the repo · `[untested]` proposed code I could not run.

> **Format change.** Weeks 1-4 were a Python `Handler`. Week 5 is a **SQL DAG**: a `dag.yml` header comment (schedule, tasks, `materialized`, `depends_on`) followed by one `-- task:` block per task, and each block is exactly 1 `SELECT`. So this analysis compares *DAG design* (how history is kept) as well as SQL expressions.

> **How I tested.** The raw tables are not in the repo. I generated synthetic `raw_payments` / `raw_fx_rates` / `raw_merchants` from the README's conditions and ran both DAGs in SQLite 3.45 (the gold file uses SQLite-style functions: `quote`, `GLOB`, `json_valid`, `datetime(..,'unixepoch')` `[inferred]`). Column formats (batch id as `YYYY-MM-DD`, ids like `pay_12345678`, merchants like `M000003`) are **assumed from the gold file**, not from the real feed. Every `[estimate]` below is on that synthetic stream.

---

## Why your score was 0

- **`fct_payments` crashed, so no table was built** `[measured]`. The README says `crashed at task fct_payments` and `Rows built 0 of 99,261`. When a task crashes, every row of the per-condition table shows 0% whatever the SQL would have done: that table says nothing about individual conditions this week.
- **The most likely cause is line 38**, `json_extract(metadata, '$.order_ref')` `[inferred]`. The README lists "JSON cut at the field width" (0.6% of tables): the landing column is fixed-width, the load cuts what does not fit, and "a JSON function handed it raises and takes the whole task with it". On my synthetic feed the same query fails with `OperationalError: malformed JSON` as soon as one metadata value is cut `[estimate]`. One bad row out of 99,261 is enough.
- **It was not a speed problem.** Work per raw row was .07x the median `[measured]`: the SQL does very little per row, which is also why it scores nothing.
- **Fixing the crash alone would not have scored well.** With the cut JSON nulled out so the query runs, your SQL produced 992 rows for 385 payments, and 0 of 291 matched rows had the right `merchant_country`, 3 of 291 the right `settled_usd` `[estimate]` (details in section 3). The sections below are what the crash was hiding.

## Impact ranking

| # | Area | Penalty | Gap vs gold |
|---|---|---|---|
| 1 | Crash on cut-off JSON | **[measured]** 0 of 99,261 rows built | Gold guards with `json_valid` and a text scan (L51-54, L79-88) |
| 2 | History tasks are plain copies; final task takes every row | `[inferred]`, 58% + 35% + 45% + 25% + 22% of tables | Gold merges into history (L7, L12, L17), then reconciles per payment (L186-203) |
| 3 | No currency conversion or unit handling | `[inferred]`, all rows with non-USD currency (25% no-rate days, 13.6% + 12.8% special decimals, 15% major units) | Gold: divisor per currency, as-of FX rate (L212-219, L228-251, L283) |
| 4 | `merchant_country` hard-coded `NULL`, test merchants kept | `[inferred]`, 100% of rows for the column (L39) | Gold: as-of join on the merchant snapshots (L252-273, L283-285, L306) |
| 5 | `settled_in_period_usd` is a copy of `settled_usd` | `[inferred]`, every payment moved after the close (18%) or paid over several nights (34.2%) | Gold sums per night, once per night (L205-227) |
| 6 | Dirty text is read as-is | `[inferred]`, 30% + 16% + 14% + 14% + 12% + 8% + 8% + ... | Gold cleans in a CTE before parsing (L27-56) |
| 7 | DAG settings | `[inferred]` | Gold: `merge` + `unique_key`, `trigger_rule: all_done` (L7-22) |

Section 1 is the cause of the 0. Sections 2-7 are upside, ranked by README share of tables. Those shares are not measured penalties, and the README gives no per-condition numbers for a crashed run.

---

## 1. Crash on cut-off JSON (the cause of the 0)

**Example input:** `metadata` = `{"order_ref": "ORD-482913", "device": "ios", "ip": "10.0.0.1"` (the closing `}` and the end of the last field were cut off by the column width).

**Your behavior:** `json_extract` raises `malformed JSON`, the whole `fct_payments` task fails, 0 rows are built.
**Gold behavior:** `json_valid(metadata)` first. If the text is not valid JSON it reads the value by scanning for `"order_ref"` as text (L54, L79-88). A cut value gives `NULL` or the text it can still read, never an error.
**Why it matters:** this single row type (0.6% of tables) zeroed the whole run `[measured]`. Other README conditions for the same field: camelCase key (12%), blank refs such as `''`, `-`, `N/A` (8%).

**Your code / Before** (`dag.sql` L38):
```sql
 38         json_extract(metadata, '$.order_ref') AS order_ref,
```

**After** (the `order_ref` part of `payments_history`; full runnable file in the Appendix):
```sql
CASE WHEN json_valid(metadata)
       THEN CAST(coalesce(json_extract(metadata,'$.order_ref'), json_extract(metadata,'$.orderRef')) AS TEXT)
     WHEN instr(metadata,'"order_ref"') > 0 THEN
       CASE WHEN substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'),1,1) = '"'
            THEN substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'), 2,
                 instr(substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'), 2), '"') - 1) END
END AS ref
...
CASE WHEN upper(trim(ref)) NOT IN ('','-','--','N/A','NULL','NONE') THEN trim(ref) END AS order_ref
```

**How it works:** `json_valid()` returns 0 for broken text instead of raising, so it is a safe test to put in front of any JSON function. Valid JSON goes through `json_extract` (and also tries the camelCase key). Broken JSON falls back to reading the text after `"order_ref"` up to the next quote. Blank markers (`''`, `-`, `N/A`) become `NULL`. This is done in the history task, so `fct_payments` never sees raw JSON. A task that parses raw text should never be allowed to raise: put every parse behind a guard (`json_valid`, `GLOB`) so a bad row becomes `NULL`, not a crash.
**Proof:** your `dag.sql` on the synthetic feed: `CRASH at task fct_payments: OperationalError: malformed JSON`. The After file on the same feed: runs, 385 rows `[estimate]`. If the value itself is cut mid-text (`"ORD-48`), the scan returns the partial text; I did not test that case `[untested]`.

---

## 2. History tasks are plain copies, final task takes every row

**Example input:** payment `pay_10000045` is copied on 3 nights (authorized, captured, captured), one of the copies loaded twice, and the later rows leave `amount`, `currency` and `created_at` empty.

**Your behavior:** `payments_history` is `SELECT * FROM raw_payments` and `fct_payments` selects from it with no `GROUP BY`, so every copy becomes an output row, and an empty field in the newest copy stays empty. Your own comment on L40 says it: "1 row per key: a second row for the same key costs 2".
**Gold behavior:** history tasks use `incremental_strategy: merge` with `unique_key: [rk]`, where `rk` is the `quote()` of every column joined with `'|'` (L29 for payments), so a rerun or a repeated row cannot be added twice. `fct_payments` then builds a sortable key `eff_day || loaded_ts || updated_ts` (L188) and, per column, takes `substr(max(CASE WHEN col IS NOT NULL THEN k || col END), 49)` (L192-203): the newest **non-empty** value of each column.
**Why it matters:** README shares of tables: copied on more than 1 night 58.0%, same row twice in 1 batch 35.0%, last row lacks older fields 45.0%, old rows in a newer batch 25.0%, state that came days late 22.0%, fixed by hand with same stamp 16.0% `[measured]`. The raw tables keep only recent copies, so the history task is the only place the older states survive.

**Your code / Before** (`dag.sql` L21-29, L32-40):
```sql
 21  -- task: payments_history
 22  SELECT *
 23  FROM raw_payments
 24  
 25  -- task: fx_rates_history
 26  SELECT * FROM raw_fx_rates;
 27  
 28  -- task: merchants_history
 29  SELECT * FROM raw_merchants;
```
```sql
 31  -- task: fct_payments
 32  SELECT payment_id,
 33         status,
 34         amount AS amount_usd,
 35         settled AS settled_usd,
 36         settled AS settled_in_period_usd,
 37         captured_at,
 38         json_extract(metadata, '$.order_ref') AS order_ref,
 39         NULL AS merchant_country
 40  FROM payments_history;   -- 1 row per key: a second row for the same key costs 2
```

**After** (`dag.yml` header and the reconcile step; full file in the Appendix):
```yaml
  payments_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_payments]
```
```sql
p AS (
  SELECT *, coalesce(eff_day,'0000-00-00') || coalesce(loaded_ts,'0000-00-00 00:00:00') || coalesce(updated_ts,'0000-00-00 00:00:00') AS k
  FROM payments_history WHERE pid GLOB 'pay_????????'
),
g AS (  -- newest NON-NULL value per column
  SELECT pid,
    nullif(substr(max(k || coalesce(status_n,'')), 49), '') AS status,
    substr(max(CASE WHEN amt IS NOT NULL THEN k || amt END), 49) AS amt,
    ...
  FROM p GROUP BY pid
)
```

**How it works:** think of each payment as a pile of snapshots. `k` puts every snapshot in time order (batch day, then load time, then the row's own update time) as one text string, so `max()` finds the newest. Putting `k` in front of the value and cutting it off with `substr(..., 49)` (10 + 19 + 19 = 48 characters of key) returns the value from the newest row. The `CASE WHEN col IS NOT NULL` makes a newer row that left the column empty lose to an older row that has it. `merge` on `rk` means a row that already exists is not added again. I took this key-and-`max()` technique from the gold file (L188-203).
**Proof:** your SQL (crash removed) returned 992 rows for 385 payments, 271 ids duplicated. The After file returned 385 rows, 0 duplicated `[estimate]`. The `merge`/`unique_key` behavior on the real platform is `[untested]` (my local run builds the history with plain `SELECT`s over all raw rows).

---

## 3. No currency conversion or unit handling

**Example input:** a JPY payment `amount = '68313'` (yen, no decimals), a KWD payment `amount = '35.490'` (3 decimals, already in major units), a USD payment created on a Saturday.

**Your behavior:** `amount AS amount_usd` (L34) and `settled AS settled_usd` (L35) copy the raw text. No currency, no rate, no unit. The column is named USD but holds minor units of whatever currency.
**Gold behavior:** a divisor per currency, 1 for the no-decimal list (JPY, KRW, CLP, ...), 1000 for the 3-decimal list (KWD, BHD, OMR, JOD, ...), else 100 (L212-219). An amount that already contains `.` is major units and is not divided (L291). The rate comes from `fx1`: latest-loaded row per (currency, day) (L228-232), then `lead(rate_day)` gives each rate its validity window, and the payment joins on `created day >= rate_day AND created day < next_day` (L248-251, L283). Gold also drops a rate that is far from the currency's median, or flips it if its inverse fits (L236-247).
**Why it matters:** README shares: created on a day with no rate 25.0%, 0 and 3 decimal currencies 13.6%, more 0 and 3 place money 12.8%, major units 15.0%, 2 rates for 1 day 8.9%, rate that came after the run 10.7% `[measured]`.

**Your code / Before** (`dag.sql` L34-36):
```sql
 34         amount AS amount_usd,
 35         settled AS settled_usd,
 36         settled AS settled_in_period_usd,
```

**After** (from the Appendix file, tasks `fx_history` and `fct_payments`):
```sql
gd AS (
  SELECT g.*, date(created_ts) AS cday,
    CASE WHEN cur IN ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') THEN 1.0
         WHEN cur IN ('BHD','IQD','JOD','KWD','LYD','OMR','TND') THEN 1000.0 ELSE 100.0 END AS dv
  FROM g
),
fx1 AS (
  SELECT cur, rate_day, rate FROM (
    SELECT cur, rate_day, rate, row_number() OVER (PARTITION BY cur, rate_day ORDER BY loaded_ts DESC, rk DESC) AS rn
    FROM fx_history WHERE cur IS NOT NULL AND rate_day IS NOT NULL AND rate > 0) WHERE rn = 1
),
fx3 AS (SELECT cur, rate_day, rate, lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day FROM fx1),
...
LEFT JOIN fx3 ON fx3.cur = gd.cur AND gd.cday >= fx3.rate_day AND (fx3.next_day IS NULL OR gd.cday < fx3.next_day)
...
CASE WHEN amt IS NULL THEN NULL WHEN instr(amt,'.') > 0 THEN CAST(amt AS REAL) ELSE CAST(amt AS REAL) / dv END * rate AS amount_raw
```

**How it works:** two steps. (1) Convert to major units: divide minor units by 1 / 100 / 1000 depending on the currency, but leave amounts that already hold a decimal point alone. (2) Multiply by the rate in force on the payment's creation day. Instead of joining on the exact date (which finds nothing on a Saturday) each rate is given an end date, the next published day, so a Saturday payment lands on Friday's rate. Keeping only the latest-loaded row per (currency, day) removes the wrong rate that was published again later. The rate sanity check from the gold file (L236-247) is **not** in my After `[not available in my version]`.
**Proof:** your SQL (crash removed): `amount_usd` right on 7 of 291 matched rows. After: 385 of 385 `[estimate]`, on a feed with weekends, corrected rates, JPY/KWD and 10% major-unit rows.

---

## 4. `merchant_country` is always NULL, test merchants are kept

**Example input:** merchant `M000003` is under `VN` on the nights before 2026-10-01 and `TH` after, and its id arrives as `3`, `m000003` or `M000003`. `M000008` is flagged test until 2026-09-24, then goes live.

**Your behavior:** `NULL AS merchant_country` (L39): the column is wrong for every row, and test merchants are not filtered.
**Gold behavior:** history rows are keyed by the normalized id (`'M' || zero-padded digits`, L103-105 and L169-171), de-duplicated per (merchant, batch day) (L252-259), given a validity window with `lead(batch_day)` (L260-267), and joined on the payment's creation day (L283-285). Final filter `WHERE is_test = 0` (L306). The test flag is read as of the payment day, not "ever a test merchant".
**Why it matters:** README: a seller that moved 9.2%, went live 7.8%, gone from the copy 7.9%, ids that lost their zeros 14.0%, ids cased by 1 app 5.0%, country cased or padded 7.9%, a night the copy never came 9.6% `[measured]`. The landing keeps only the latest merchants copy, so only a history task can answer "which country on the day of the payment".

**Your code / Before** (`dag.sql` L28-29, L39):
```sql
 28  -- task: merchants_history
 29  SELECT * FROM raw_merchants;
...
 39         NULL AS merchant_country
```

**After** (tasks `merchants_history` and `fct_payments`, excerpt):
```sql
mc AS (SELECT mid, batch_day, country, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day FROM m1 WHERE country IS NOT NULL),
mt AS (SELECT mid, batch_day, is_test, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day FROM m1 WHERE is_test IS NOT NULL),
...
LEFT JOIN mc  ON mc.mid  = gd.mid AND gd.cday >= mc.batch_day AND (mc.next_day IS NULL OR gd.cday < mc.next_day)
LEFT JOIN mt  ON mt.mid  = gd.mid AND gd.cday >= mt.batch_day AND (mt.next_day IS NULL OR gd.cday < mt.next_day)
...
FROM v WHERE is_test = 0;
```

**How it works:** same trick as the FX rate. Each night's merchant snapshot is valid until the next snapshot, so a payment looks up the snapshot in force on its creation day. The night 2026-10-05 has no copy in my test: the previous snapshot is simply still in force, which is why an as-of join survives a missing night. A merchant that is *later* deleted from the source stays in the history task as long as the history task ran the night it was present. My version has no fallback for a payment created before a merchant's first snapshot (gold L268-274 uses `mf`) `[not available in my version]`.
**Proof:** your SQL (crash removed): `merchant_country` right on 0 of 291. After: 385 of 385, and the test merchant's early payments are excluded `[estimate]`.

---

## 5. `settled_in_period_usd` is a copy of `settled_usd`

**Example input:** a payment paid out on nights 10-11 (60.00), 10-13 (40.00) and a dispute on 10-17 (-15.00). The books close on 2026-10-12.

**Your behavior:** `settled AS settled_usd` and `settled AS settled_in_period_usd` (L35-36) both take one night's text. Neither adds the nights, and the two columns are always equal.
**Gold behavior:** one movement per (payment, night): the newest row of that night wins, so a day sent twice is replaced, not added (L205-211). Then it sums all nights for `settled_usd` and only the nights inside the window for `settled_in_period_usd` (L220-227), converting each night to minor units first.
**Why it matters:** README: paid out over several nights 34.2%, money that moved after 18.0%, money taken back later 9.3%, a day sent twice over 18.0% `[measured]`. A night counted twice overstates the figure, a night never read is missing.
**Window caveat:** gold hard-codes `BETWEEN '2026-02-02' AND '2026-02-26'` (L223), which does not match the 2026-10-12 close in the README `[inferred]`. My After uses `eff_day <= '2026-10-12'` (the README says finance closes "through 2026-10-12"), and the start of the period is `[not available]`.

**Your code / Before** (`dag.sql` L35-36):
```sql
 35         settled AS settled_usd,
 36         settled AS settled_in_period_usd,
```

**After** (task `fct_payments`):
```sql
sd AS (  -- 1 movement per (payment, night)
  SELECT pid, eff_day, substr(max(coalesce(loaded_ts,'0000-00-00 00:00:00') || coalesce(updated_ts,'0000-00-00 00:00:00') || stl), 39) AS stl
  FROM p WHERE stl IS NOT NULL GROUP BY pid, eff_day
),
st AS (
  SELECT sd.pid,
    sum(CASE WHEN instr(sd.stl,'.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END) AS st_all,
    sum(CASE WHEN sd.eff_day <= '2026-10-12' THEN
          CASE WHEN instr(sd.stl,'.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END ELSE 0 END) AS st_in
  FROM sd JOIN gd ON gd.pid = sd.pid GROUP BY sd.pid
)
```

**How it works:** the raw `settled` column is not the payment's total, it is what moved *that night*. So first reduce to one number per payment per night (a night loaded twice collapses to one), then add the nights up. Negative movements (disputes) are added like any other. A second sum with a date condition gives the in-period figure, so money that moved after 2026-10-12 counts in `settled_usd` but not in `settled_in_period_usd`.
**Proof:** your SQL (crash removed): `settled_usd` right on 3 of 291, `settled_in_period_usd` 3 of 291. After: 385 of 385 and 385 of 385 `[estimate]`, but the synthetic truth uses the same `<= 2026-10-12` rule I coded, so this checks the arithmetic, not the real window `[inferred]`.

---

## 6. Dirty text is read as-is

**Example input:** `'NULL'`, `'\N'`, `''` or `'N/A'` in `captured_at`; ` PAY_10000045 ` (upper-case, padded); status ` AUTHORISED `; timestamps as `2026-10-05T04:43:59Z`, `2026-10-05 04:43:59+00:00`, `...59.123Z`, `...+05:30`, epoch seconds, epoch milliseconds.

**Your behavior:** `status`, `captured_at` and `payment_id` are copied as they are. A null marker is a value; ` PAY_1 ` and `pay_1` are 2 payments; a text sort puts `03:30+05:30` after `01:00+00` although it was earlier.
**Gold behavior:** a cleaning CTE `c` trims and turns null-like text into `NULL` (16 markers, L27-44), then a parse CTE turns every timestamp spelling into one UTC form (epoch seconds vs ms by size, offsets, `Z`, `UTC`) (L57-78), maps status words (`authorised` to `authorized`) (L106-109), and lowers payment ids and pads merchant ids (L102-105).
**Why it matters:** README: NULL landed as text 30.0%, words of the other gateway 16.0%, times in a local offset 14.0%, epoch time in a text field 14.0%, ids that lost their zeros 14.0%, camel case key 12.0%, status casing 8.0%, UTC spelt 3 ways 8.0% `[measured]`.

**Your code / Before** (`dag.sql` L32-33, L37):
```sql
 32  SELECT payment_id,
 33         status,
...
 37         captured_at,
```

**After** (the first two CTEs of `payments_history`, with the helper written out once; the Appendix repeats it per column):
```sql
-- null-like text -> NULL, trimmed (applied to every raw column)
CASE WHEN upper(trim(x, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(x, ' '||char(9,10,13)) END

-- any timestamp spelling -> 'YYYY-MM-DD HH:MM:SS' (UTC), or NULL, never an error
CASE WHEN x IS NULL THEN NULL
     WHEN x NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(x AS REAL) >= 1e11 THEN datetime(CAST(x AS REAL)/1000.0,'unixepoch')
                                           WHEN CAST(x AS REAL) >= 1e8  THEN datetime(CAST(x AS REAL),'unixepoch') END
     ELSE datetime(replace(upper(x),' UTC','')) END
```

**How it works:** clean first, parse second, never mix. A value that is all digits is a count of seconds (about 1.7e9) or milliseconds (about 1.7e12), told apart by size. Anything else goes to SQLite's `datetime()`, which understands `T`, `Z`, fractions and a `+05:30` offset and converts to UTC, and returns `NULL` instead of raising when it cannot read the text. After this step ordering by time is a plain text sort of one format.
**Not handled:** an offset written as `+00` or `+0530` (gold appends `:00` or inserts a colon, L61-62, L66-67); the real feed may use it `[not available]`. `refused`, `cancelled` and `chargeback` (README, "words of the other gateway") are not mapped in my version, and gold maps only `authorised` (L106-109), so I do not know whether they reach the table `[not available]`.
**Proof:** After: `status` 385/385, `captured_at` 385/385, `payment_id` 385/385 on a feed with all six timestamp spellings, padded/upper-case ids and 4 null markers `[estimate]`. Your SQL (crash removed): `status` 60/291, `captured_at` 23/291.

---

## 7. DAG settings

**Your code / Before** (`dag.sql` L1-17):
```yaml
  1  /* dag.yml
  2  dag: the_close
  3  schedule: nightly
  4  tasks:                      # depends_on = the edges; materialized: table | incremental | snapshot | view | test | sensor
  5    payments_history:
  6      materialized: incremental
  7      depends_on: [raw_payments]
  8    fx_rates_history:
  9      materialized: incremental
 10      depends_on: [raw_fx_rates]
 11    merchants_history:
 12      materialized: incremental
 13      depends_on: [raw_merchants]
 14    fct_payments:
 15      materialized: table
 16      depends_on: [payments_history, fx_rates_history, merchants_history]
 17  */
```

**Gold** (L1-23): `incremental_strategy: merge` and `unique_key: [rk]` on the three history tasks (L7, L12, L17); `trigger_rule: all_done` on `fct_payments` (L22).

**After:** the header in the Appendix.
**How it works:** `materialized: incremental` says "keep what is already there and add new rows". Without a strategy and a key I cannot tell from the repo how a rerun treats a repeated row `[not available]`; `merge` on a key that identifies the exact row makes a rerun harmless. `trigger_rule: all_done` runs `fct_payments` even if an upstream task failed, so one bad history task does not leave you with no table at all. Your header declared the task named `fx_rates_history`; gold calls it `fx_history`. Names do not matter as long as `depends_on` and the `-- task:` block use the same one.
**Proof:** none: whether `merge` and `all_done` behave as I describe on the platform is `[untested]`.

---

## Not compared

- Gold's rate sanity check (`fx2`, L236-247) and its `mf` fallback for a merchant with no snapshot on the payment day (L268-274) are **not** in my After. I did not test them against the synthetic feed.
- Conditions I did not model in the synthetic feed: landed after the run time, a state that came days late (needs running the DAG night by night), a rate that came after the run, a seller gone from the copy, JSON cut inside the order reference value.
- The platform's real column formats. Everything is `[estimate]` on a feed I wrote.

## Recommended pattern

Four tasks, same shape as gold: three history tasks that clean, parse and keep every row (merge on a row key), and one final task that (1) picks the newest non-null value per column per payment, (2) sums one movement per night, (3) joins rate and merchant **as of the payment day**.

```
raw_*  ->  clean CTE (null markers, trim)
       ->  parse CTE  (timestamps, ids, status, numbers, JSON behind json_valid)
       ->  *_history  (merge on rk)
*_history -> fct_payments: newest non-null per payment | 1 row per (payment, night) summed | as-of joins | WHERE is_test = 0
```

## Checklist (run-level failures)

- Can any parse raise on a bad row? Put `json_valid`, `GLOB` or a `CASE` guard in front of every JSON function, `CAST` and date function.
- Does the final task depend on one upstream task that could fail? Set `trigger_rule: all_done` and check what happens with an empty upstream table.
- Does each history task keep what raw will drop, and is a rerun safe (`merge` + a key that is the whole row)?
- Is the newest value taken **per column**, ignoring empty ones, not "the newest row"?
- Is every rate and every merchant fact taken **as of the payment day** (end-date each row with `lead()`), not by exact date?
- Is each night counted exactly once, and does the in-period figure use the close window?
- Run it on a small table with one cut-off JSON value, one null marker, one Saturday payment and one duplicated night before submitting.

---

## Appendix: complete runnable After (`dag.sql`)

Tested end to end on the synthetic feed (SQLite 3.45): 385 rows, 385 payment ids found, each of the 7 non-key columns right on 385 of 385 `[estimate]`. The `merge` / `all_done` header is `[untested]` on the platform.

```sql
/* dag.yml
dag: the_close
schedule: nightly
tasks:
  payments_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_payments]
  fx_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_fx_rates]
  merchants_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [rk]
    depends_on: [raw_merchants]
  fct_payments:
    materialized: table
    trigger_rule: all_done
    depends_on: [payments_history, fx_history, merchants_history]
*/

-- task: payments_history
WITH c AS (
  SELECT quote(payment_id)||'|'||quote(merchant_id)||'|'||quote(amount)||'|'||quote(currency)||'|'||quote(status)||'|'||quote(settled)||'|'||quote(created_at)||'|'||quote(captured_at)||'|'||quote(updated_at)||'|'||quote(metadata)||'|'||quote(_batch_id)||'|'||quote(_correction_for)||'|'||quote(_loaded_at) AS rk,
    CASE WHEN upper(trim(payment_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(payment_id, ' '||char(9,10,13)) END AS payment_id, CASE WHEN upper(trim(merchant_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(merchant_id, ' '||char(9,10,13)) END AS merchant_id, CASE WHEN upper(trim(amount, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(amount, ' '||char(9,10,13)) END AS amount, CASE WHEN upper(trim(currency, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(currency, ' '||char(9,10,13)) END AS currency,
    CASE WHEN upper(trim(status, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(status, ' '||char(9,10,13)) END AS status, CASE WHEN upper(trim(settled, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(settled, ' '||char(9,10,13)) END AS settled, CASE WHEN upper(trim(created_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(created_at, ' '||char(9,10,13)) END AS cr, CASE WHEN upper(trim(captured_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(captured_at, ' '||char(9,10,13)) END AS ca,
    CASE WHEN upper(trim(updated_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(updated_at, ' '||char(9,10,13)) END AS up, CASE WHEN upper(trim(metadata, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(metadata, ' '||char(9,10,13)) END AS metadata, CASE WHEN upper(trim(_batch_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid, CASE WHEN upper(trim(_loaded_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS lo
  FROM raw_payments
),
t AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, bid,
    CASE WHEN cr IS NULL THEN NULL WHEN cr NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(cr AS REAL) >= 1e11 THEN datetime(CAST(cr AS REAL)/1000.0,'unixepoch') WHEN CAST(cr AS REAL) >= 1e8 THEN datetime(CAST(cr AS REAL),'unixepoch') END ELSE datetime(replace(upper(cr),' UTC','')) END AS created_ts, CASE WHEN ca IS NULL THEN NULL WHEN ca NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(ca AS REAL) >= 1e11 THEN datetime(CAST(ca AS REAL)/1000.0,'unixepoch') WHEN CAST(ca AS REAL) >= 1e8 THEN datetime(CAST(ca AS REAL),'unixepoch') END ELSE datetime(replace(upper(ca),' UTC','')) END AS captured_ts, CASE WHEN up IS NULL THEN NULL WHEN up NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(up AS REAL) >= 1e11 THEN datetime(CAST(up AS REAL)/1000.0,'unixepoch') WHEN CAST(up AS REAL) >= 1e8 THEN datetime(CAST(up AS REAL),'unixepoch') END ELSE datetime(replace(upper(up),' UTC','')) END AS updated_ts, CASE WHEN lo IS NULL THEN NULL WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL)/1000.0,'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL),'unixepoch') END ELSE datetime(replace(upper(lo),' UTC','')) END AS loaded_ts,
    CASE WHEN json_valid(metadata) THEN CAST(coalesce(json_extract(metadata,'$.order_ref'), json_extract(metadata,'$.orderRef')) AS TEXT)
         WHEN instr(metadata,'"order_ref"') > 0 THEN
           CASE WHEN substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'),1,1) = '"'
                THEN substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'), 2,
                     instr(substr(ltrim(substr(metadata, instr(metadata,'"order_ref"')+11), ' :'), 2), '"') - 1) END
    END AS ref
  FROM c
)
SELECT rk,
  lower(payment_id) AS pid,
  CASE WHEN upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]' THEN upper(merchant_id) WHEN merchant_id NOT GLOB '*[^0-9]*' AND length(merchant_id) BETWEEN 1 AND 6 THEN 'M'||substr('000000'||merchant_id,-6) ELSE upper(merchant_id) END AS mid,
  CASE lower(status) WHEN 'authorized' THEN 'authorized' WHEN 'authorised' THEN 'authorized' WHEN 'captured' THEN 'captured'
       WHEN 'failed' THEN 'failed' WHEN 'voided' THEN 'voided' WHEN 'disputed' THEN 'disputed' END AS status_n,
  CASE WHEN amount NOT GLOB '*[^0-9.]*' AND amount GLOB '*[0-9]*' AND amount NOT GLOB '*.*.*' THEN amount END AS amt,
  CASE WHEN settled GLOB '*[0-9]*' AND settled NOT GLOB '*[^0-9.-]*' AND settled NOT GLOB '?*-*' AND settled NOT GLOB '*.*.*' THEN settled END AS stl,
  CASE WHEN upper(currency) GLOB '[A-Z][A-Z][A-Z]' THEN upper(currency) END AS cur,
  created_ts, captured_ts, updated_ts, loaded_ts,
  CASE WHEN upper(trim(ref)) NOT IN ('','-','--','N/A','NULL','NONE') THEN trim(ref) END AS order_ref,
  coalesce(CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid,1,10)) END, date(loaded_ts, '-1 day')) AS eff_day
FROM t;

-- task: fx_history
WITH c AS (
  SELECT quote(rate_date)||'|'||quote(currency)||'|'||quote(usd_rate)||'|'||quote(_batch_id)||'|'||quote(_loaded_at) AS rk, upper(CASE WHEN upper(trim(currency, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(currency, ' '||char(9,10,13)) END) AS cur, CASE WHEN upper(trim(rate_date, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(rate_date, ' '||char(9,10,13)) END AS rd, CASE WHEN upper(trim(usd_rate, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(usd_rate, ' '||char(9,10,13)) END AS rate,
    CASE WHEN upper(trim(_batch_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid, CASE WHEN upper(trim(_loaded_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS lo
  FROM raw_fx_rates
)
SELECT rk, CASE WHEN cur GLOB '[A-Z][A-Z][A-Z]' THEN cur END AS cur,
  coalesce(CASE WHEN rd GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(rd,1,10)) END, CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid,1,10)) END) AS rate_day,
  CASE WHEN rate NOT GLOB '*[^0-9.]*' AND rate GLOB '*[0-9]*' AND rate NOT GLOB '*.*.*' AND CAST(rate AS REAL) > 0 THEN CAST(rate AS REAL) END AS rate,
  CASE WHEN lo IS NULL THEN NULL WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL)/1000.0,'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL),'unixepoch') END ELSE datetime(replace(upper(lo),' UTC','')) END AS loaded_ts
FROM c;

-- task: merchants_history
WITH c AS (
  SELECT quote(merchant_id)||'|'||quote(name)||'|'||quote(country)||'|'||quote(is_test)||'|'||quote(_batch_id)||'|'||quote(_loaded_at) AS rk, CASE WHEN upper(trim(merchant_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(merchant_id, ' '||char(9,10,13)) END AS merchant_id, upper(CASE WHEN upper(trim(country, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(country, ' '||char(9,10,13)) END) AS country, lower(CASE WHEN upper(trim(is_test, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(is_test, ' '||char(9,10,13)) END) AS is_test,
    CASE WHEN upper(trim(_batch_id, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid, CASE WHEN upper(trim(_loaded_at, ' '||char(9,10,13))) IN ('','NULL','NONE','N/A','NAN','\N','-','--') THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS lo
  FROM raw_merchants
)
SELECT rk, CASE WHEN upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]' THEN upper(merchant_id) WHEN merchant_id NOT GLOB '*[^0-9]*' AND length(merchant_id) BETWEEN 1 AND 6 THEN 'M'||substr('000000'||merchant_id,-6) ELSE upper(merchant_id) END AS mid,
  CASE WHEN country GLOB '[A-Z][A-Z]' THEN country END AS country,
  CASE WHEN is_test IN ('t','true','1','y','yes') THEN 1 WHEN is_test IN ('f','false','0','n','no') THEN 0 END AS is_test,
  coalesce(CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid,1,10)) END, date(CASE WHEN lo IS NULL THEN NULL WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL)/1000.0,'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL),'unixepoch') END ELSE datetime(replace(upper(lo),' UTC','')) END, '-1 day')) AS batch_day,
  CASE WHEN lo IS NULL THEN NULL WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL)/1000.0,'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL),'unixepoch') END ELSE datetime(replace(upper(lo),' UTC','')) END AS loaded_ts
FROM c;

-- task: fct_payments
WITH p AS (
  SELECT *, coalesce(eff_day,'0000-00-00') || coalesce(loaded_ts,'0000-00-00 00:00:00') || coalesce(updated_ts,'0000-00-00 00:00:00') AS k
  FROM payments_history WHERE pid GLOB 'pay_????????'
),
g AS (  -- newest NON-NULL value per column (a newer row may leave columns empty)
  SELECT pid,
    nullif(substr(max(k || coalesce(status_n,'')), 49), '') AS status,
    substr(max(CASE WHEN amt IS NOT NULL THEN k || amt END), 49) AS amt,
    substr(max(CASE WHEN cur IS NOT NULL THEN k || cur END), 49) AS cur,
    substr(max(CASE WHEN created_ts IS NOT NULL THEN k || created_ts END), 49) AS created_ts,
    substr(max(CASE WHEN mid IS NOT NULL THEN k || mid END), 49) AS mid,
    substr(max(CASE WHEN order_ref IS NOT NULL THEN k || order_ref END), 49) AS order_ref,
    substr(max(CASE WHEN captured_ts IS NOT NULL THEN k || captured_ts END), 49) AS cap_any
  FROM p GROUP BY pid
),
gd AS (
  SELECT g.*, date(created_ts) AS cday,
    CASE WHEN cur IN ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') THEN 1.0
         WHEN cur IN ('BHD','IQD','JOD','KWD','LYD','OMR','TND') THEN 1000.0 ELSE 100.0 END AS dv
  FROM g
),
sd AS (  -- 1 movement per (payment, night): a night sent twice is replaced, not added
  SELECT pid, eff_day, substr(max(coalesce(loaded_ts,'0000-00-00 00:00:00') || coalesce(updated_ts,'0000-00-00 00:00:00') || stl), 39) AS stl
  FROM p WHERE stl IS NOT NULL GROUP BY pid, eff_day
),
st AS (
  SELECT sd.pid,
    sum(CASE WHEN instr(sd.stl,'.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END) AS st_all,
    sum(CASE WHEN sd.eff_day <= '2026-10-12' THEN
          CASE WHEN instr(sd.stl,'.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END ELSE 0 END) AS st_in
  FROM sd JOIN gd ON gd.pid = sd.pid GROUP BY sd.pid
),
fx1 AS (  -- 1 rate per (currency, day): the latest published wins
  SELECT cur, rate_day, rate FROM (
    SELECT cur, rate_day, rate, row_number() OVER (PARTITION BY cur, rate_day ORDER BY loaded_ts DESC, rk DESC) AS rn
    FROM fx_history WHERE cur IS NOT NULL AND rate_day IS NOT NULL AND rate > 0) WHERE rn = 1
),
fx3 AS (SELECT cur, rate_day, rate, lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day FROM fx1),
m1 AS (
  SELECT mid, batch_day, country, is_test FROM (
    SELECT mid, batch_day, country, is_test, row_number() OVER (PARTITION BY mid, batch_day ORDER BY loaded_ts DESC, rk DESC) AS rn
    FROM merchants_history WHERE mid IS NOT NULL AND batch_day IS NOT NULL) WHERE rn = 1
),
mc AS (SELECT mid, batch_day, country, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day FROM m1 WHERE country IS NOT NULL),
mt AS (SELECT mid, batch_day, is_test, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day FROM m1 WHERE is_test IS NOT NULL),
j AS (
  SELECT gd.*,
    coalesce(fx3.rate, CASE WHEN gd.cur = 'USD' THEN 1.0 END) AS rate,
    mc.country AS country, coalesce(mt.is_test, 0) AS is_test,
    coalesce(st.st_all, 0) AS st_all, coalesce(st.st_in, 0) AS st_in
  FROM gd
  LEFT JOIN fx3 ON fx3.cur = gd.cur AND gd.cday >= fx3.rate_day AND (fx3.next_day IS NULL OR gd.cday < fx3.next_day)
  LEFT JOIN mc  ON mc.mid  = gd.mid AND gd.cday >= mc.batch_day AND (mc.next_day IS NULL OR gd.cday < mc.next_day)
  LEFT JOIN mt  ON mt.mid  = gd.mid AND gd.cday >= mt.batch_day AND (mt.next_day IS NULL OR gd.cday < mt.next_day)
  LEFT JOIN st  ON st.pid  = gd.pid
),
v AS (
  SELECT j.*,
    CASE WHEN amt IS NULL THEN NULL WHEN instr(amt,'.') > 0 THEN CAST(amt AS REAL) ELSE CAST(amt AS REAL) / dv END * rate AS amount_raw,
    st_all / dv * rate AS settled_raw, st_in / dv * rate AS in_raw
  FROM j
)
SELECT pid AS payment_id, status,
  round(amount_raw + CASE WHEN amount_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS amount_usd,
  round(settled_raw + CASE WHEN settled_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS settled_usd,
  round(in_raw + CASE WHEN in_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS settled_in_period_usd,
  replace(cap_any, ' ', 'T') || 'Z' AS captured_at,
  order_ref, country AS merchant_country
FROM v WHERE is_test = 0;
```
