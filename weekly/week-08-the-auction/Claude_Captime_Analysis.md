# Week 8: why `dag.sql` fits the run and `captime_error_submit.sql` does not

Evidence tags: `[measured]` from the platform message you pasted, `[inferred]` from reading the code, `[estimate]` from a local test on synthetic data (SQLite with shims), `[untested]`.

## What the platform reported [measured]

`captime_error_submit.sql` stopped at task `ad_impressions`: "ran past the 1m practice cap", 5m 38s of the 10m full-schedule budget at that pace, 0 of 0 tasks and rows scored. The cap is a pass/fail gate, so a run that crosses it scores nothing, however correct the SQL is.

## The two files differ in 2 places, and both are in `ad_impressions`

Everything before `ad_impressions` (the 4 history/version tasks) is the same, and takes about the same time in both files [estimate].

### Difference 1: how a serve finds its account version (the main cost)

**`captime_error_submit.sql` (L252-L277):**

```sql
account_choices AS (
    SELECT s.impression_id, s.customer_id, s.served_at, s.detail, a.time_zone,
           ROW_NUMBER() OVER (
               PARTITION BY s.impression_id
               ORDER BY
                   CASE WHEN a.load_ts <= s.served_ts THEN 0 ELSE 1 END,
                   CASE WHEN a.load_ts <= s.served_ts THEN a.load_ts END DESC,
                   CASE WHEN a.load_ts >  s.served_ts THEN a.load_ts END ASC
           ) AS account_rank
    FROM serve AS s
    LEFT JOIN acct AS a
           ON a.customer_id = s.customer_id
),
```

- The join has only `customer_id` as its condition. Every serve is joined to **every** snapshot of its account that `accounts_history` holds (up to 1 per night, so up to 30 by the last night).
- Only afterwards does `ROW_NUMBER()` sort that large intermediate result with a 3-key `ORDER BY` to keep 1 row per serve.
- Example [estimate]: 13,564 impressions joined to 904 account snapshots gave **316,773 rows** to sort, 23 times the rows needed, and it grows each night as snapshots accumulate.
- The whole thing is rebuilt from scratch every night, because `ad_impressions` is `materialized: table` (L34-L36 in the yaml).

**`dag.sql` (L261-L292):**

```sql
acct_iv AS (
    SELECT customer_id, time_zone, load_ts,
           ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY load_ts, account_key) AS vn,
           LEAD(load_ts) OVER (PARTITION BY customer_id ORDER BY load_ts, account_key) AS next_ts
    FROM acct
),

serve_account AS (
    SELECT s.impression_id, s.customer_id, s.served_at, s.detail,
           DATE(TZ_CONVERT(s.served_at, 'UTC', COALESCE(a.time_zone, 'UTC')))::date AS served_date
    FROM serve AS s
    LEFT JOIN acct_iv AS a
           ON a.customer_id = s.customer_id
          AND (a.vn = 1 OR a.load_ts <= s.served_ts)
          AND (a.next_ts IS NULL OR s.served_ts < a.next_ts)
),
```

- The windows run once over the small accounts table and turn each snapshot into a validity interval `[load_ts, next_ts)`.
- The join then keeps only the interval that contains the serve time, so each serve matches **at most 1** row. `a.vn = 1` lets the first version also cover serves before it, which is what the captime file's second `ORDER BY` key did.
- There is no window over the serve-by-snapshot product, so the sort and the memory it needs disappear.
- Think of a card index: captime pulls out every card of the account and then sorts to find the right one; `dag.sql` has already written the date range on each card, so the serve goes straight to the right one.

### Difference 2: incremental merge instead of a full table

`dag.sql` declares `ad_impressions` as `materialized: incremental`, `incremental_strategy: merge`, `unique_key: impression_id`, and in its `ev` CTE (L236-L239) restricts the rebuild to impressions seen in `event_version`:

```sql
{% if is_incremental() %}
  AND impression_id IN (SELECT impression_id FROM event_version
                        WHERE impression_id IS NOT NULL)
{% endif %}
```

- The commented-out lines at the top of `dag.sql` (L34-L36) are exactly the captime configuration, so this was the change you made.
- **Honest limit [estimate]:** in my local test `event_version` is itself a merge table that keeps growing, so the filter did not narrow the work. `dag.sql` with `ad_impressions` forced to a full rebuild took 9.5 s against 10.4 s incremental. Whether the platform's `event_version` narrows the way the filter intends is `[untested]`. I would not rely on Difference 2 as the reason it passes.

## Measured effect of each difference [estimate]

30 nights of synthetic data, same seed, `ad_impressions` task time summed over all nights:

| Scale (impressions) | captime (table, all-snapshot join) | `dag.sql` (interval join, incremental) | `dag.sql` forced to full rebuild |
|---|---|---|---|
| 4,058 | 9.2 s | 3.0 s | not run |
| 13,564 | 31.2 s | 10.4 s | 9.5 s |

- `ad_impressions` is 3.0 to 3.3 times slower in the captime file. The other 4 tasks cost the same in both.
- **The output is identical**: the two files returned the same 4,058 rows, row for row, at the smaller scale. So the captime file is not wrong, only too expensive.
- The cost of the captime join grows with impressions times snapshots per account, and a full rebuild repeats it on every one of the 30 nights, so the total grows faster than the data. The real data has 170,216 expected rows [measured], 12 times my larger test, so the gap is larger there. The 5m 38s you saw is the platform's own pace [measured]; I did not reproduce its absolute time.

## The fix

Use `dag.sql` as is. If you want to keep the captime file's structure, the minimal change is:

1. Replace `account_choices` and `serve_account` (L252-L277) with the `acct` / `acct_iv` / `serve_account` block of `dag.sql` (L261-L292).
2. Change the yaml for `ad_impressions` to `materialized: incremental`, `depends_on: [ad_events_history, accounts_history, event_version]`, `incremental_strategy: merge`, `unique_key: [impression_id]`, and add the `is_incremental()` filter to the `ev` CTE.

Step 1 is the one the timing supports. Step 2 keeps the work from growing if the platform narrows it as intended.

## What to take from it

A join that matches on the key alone and then ranks is a hidden multiplier: the intermediate result is rows-per-key times larger than the output, and every night it is rebuilt. Turn the history into validity intervals first, so the join cannot match more than one row. The same idea applies to any "latest version as of a date" lookup in these DAGs.
