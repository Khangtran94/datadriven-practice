# Week 8 — Runtime comparison: `dag.sql` vs `captime_error_submit.sql`

## Purpose

This note explains why the submitted `dag.sql` is the more runtime-conscious version, while `captime_error_submit.sql` hit the practice runtime cap at `ad_impressions`.

The important distinction is not the number of SQL statements: both versions use the same four preparation/history tasks and the same final target task. The key difference is how the final task associates every served impression with the correct historical account version.

## 1. What the runtime message tells us

The failed run reported:

- Practice cap: **1 minute**
- Stopped at: **`ad_impressions`**
- Full-schedule pace estimate: **5m 38s / 10m**

This points to the final `ad_impressions` query as the task that exceeded the practice limit. It does **not** mean the SQL was invalid. A task can produce logically valid SQL and still fail the runtime gate because its joins and window operations do too much work.

The schedule-wide 10-minute cap is a separate gate from the 1-minute practice cap shown in this error. The 5m38s figure is the displayed full-schedule pace estimate; it should not be interpreted as proof that the stopped practice task completed successfully.

## 2. The decisive difference: account-history matching

Both submissions need the advertiser's time zone that was in force when an ad was served. `accounts` is only the latest nightly snapshot, so the pipeline first preserves account versions in `accounts_history`.

The two final queries then use different strategies.

### `captime_error_submit.sql`: join every serve to every account version, then rank

Its relevant flow is:

```sql
acct AS (
    SELECT customer_id, time_zone,
           load_at::timestamptz AS load_ts
    FROM accounts_history
),

account_choices AS (
    SELECT s.impression_id, ...,
           a.time_zone,
           ROW_NUMBER() OVER (
               PARTITION BY s.impression_id
               ORDER BY
                   CASE WHEN a.load_ts <= s.served_ts THEN 0 ELSE 1 END,
                   CASE WHEN a.load_ts <= s.served_ts THEN a.load_ts END DESC,
                   CASE WHEN a.load_ts > s.served_ts THEN a.load_ts END ASC
           ) AS account_rank
    FROM serve AS s
    LEFT JOIN acct AS a
           ON a.customer_id = s.customer_id
),

serve_account AS (
    SELECT ...
    FROM account_choices
    WHERE account_rank = 1
)
```

The join condition is only:

```sql
ON a.customer_id = s.customer_id
```

That means a serve can join to **all historical versions** for its customer. If a customer has many account snapshots, each of its serves is expanded into many candidate rows. The query then has to rank those candidates with a window function and discard all but one.

As the history grows over 30 nightly runs, this creates a large intermediate relation and a potentially expensive sort/window operation. The cost is paid again when the final task is rebuilt as a table on each run.

### `dag.sql`: turn account versions into validity intervals first

The improved query does this instead:

```sql
acct_iv AS (
    SELECT customer_id, time_zone, load_ts,
           ROW_NUMBER() OVER (
               PARTITION BY customer_id
               ORDER BY load_ts, account_key
           ) AS vn,
           LEAD(load_ts) OVER (
               PARTITION BY customer_id
               ORDER BY load_ts, account_key
           ) AS next_ts
    FROM acct
),

serve_account AS (
    SELECT ...
    FROM serve AS s
    LEFT JOIN acct_iv AS a
           ON a.customer_id = s.customer_id
          AND (a.vn = 1 OR a.load_ts <= s.served_ts)
          AND (a.next_ts IS NULL OR s.served_ts < a.next_ts)
)
```

Instead of generating all candidate versions for every serve and ranking them afterwards, it calculates each account version's time interval once:

- `load_ts` is the start of that version.
- `next_ts` is the start of the next version.
- A serve belongs to the version whose interval contains its timestamp.
- `vn = 1` also allows the first known version to cover serves before the first recorded snapshot, matching the fallback behavior intended by the earlier query.

This is an interval/range join. It expresses the temporal lookup directly in the join predicate and avoids the per-impression `ROW_NUMBER()` over the expanded serve-to-version candidates.

**Why this matters:** the expensive work moves from ranking a potentially large serve × account-version result to calculating account boundaries and matching a serve to its applicable interval. That is the central optimization in the final task.

## 3. A second difference: final-task materialization

The task declarations differ:

| Item | `dag.sql` | `captime_error_submit.sql` |
|---|---|---|
| `ad_impressions` materialization | `incremental` | `table` |
| Merge key | `impression_id` | None |
| Dependencies | `ad_events_history`, `accounts_history`, `event_version` | `ad_events_history`, `accounts_history` |

A table materialization rebuilds the target from its SELECT on every scheduled run. Across 30 nights, the expensive final query is repeatedly evaluated against the growing history.

The `dag.sql` version declares the target incremental and gives it `impression_id` as its merge key. It also contains this filter in `ev`:

```sql
{% if is_incremental() %}
AND impression_id IN (
    SELECT impression_id
    FROM event_version
    WHERE impression_id IS NOT NULL
)
{% endif %}
```

The intent is to limit final-task work to impressions represented in the event-version input for the current build, while merging results by impression ID instead of rebuilding the entire target table.

The amount of work this filter actually removes depends on the runner's incremental-table semantics and on how many IDs are present in `event_version`. It should therefore be viewed as an additional optimization, not as the only explanation for the runtime difference. The account interval join is the clear SQL-level reduction in intermediate join/ranking work.

## 4. What did not cause the cap-time failure?

The two files share the same broad preparation strategy:

1. `event_version` cleans and standardizes raw event fields, then creates `event_key` and deduplicates versions.
2. `ad_events_history` retains event rows across runs, adding only keys not already in its history.
3. `account_version` cleans account IDs, currency codes and load timestamps, creates `account_key`, and deduplicates account versions.
4. `accounts_history` retains account versions across runs.
5. `ad_impressions` combines serves, account time zones, clicks and fraud verdicts into one row per impression.

The runtime error names `ad_impressions`, so the evidence points to the final query's workload rather than a syntax problem in the preparation tasks. The upstream history tables are necessary: raw `ad_events` retains only three nights, and raw `accounts` retains only the latest snapshot. Removing those histories would make the job faster by losing information required for correct results.

## 5. Why the interval join is a better execution shape

Consider one customer with 30 account versions and 100,000 served impressions.

- **Candidate-and-rank approach:** the customer can contribute up to 3,000,000 candidate serve/version rows before the ranking filter removes all but one account version per impression.
- **Interval approach:** account boundaries are calculated over the 30 versions, and each serve is matched against the version interval containing its timestamp. It avoids deliberately constructing and ranking that full candidate set.

This is an illustration of the shape of the work, not a measured row count from the hidden dataset. Actual join cardinality depends on the data and query engine.

## 6. Important correctness checks after optimizing

The faster query must still preserve the business rules. In particular, verify these cases when testing:

- A serve before the first retained account version uses the first known time zone.
- A serve exactly at a version's `load_ts` uses that new version.
- A serve before `next_ts` stays with the previous version; a serve at `next_ts` moves to the next version.
- Multiple account records with the same effective timestamp have a deterministic ordering. `account_key` is used as a tie-breaker in the window ordering.
- An account time-zone change affects the local `served_date` only from the effective version onward.

There is also a separate incremental-correctness consideration: if a historical account version is added or corrected but no corresponding impression ID is included in the final task's incremental input, an already-materialized impression may need to be revisited. Runtime optimization must not silently prevent required historical rows from being recomputed.

## 7. Conclusion

`captime_error_submit.sql` uses a broad temporal join: every serve is paired with all versions of that customer's account, then a window function sorts and ranks the candidates. It also rebuilds `ad_impressions` as a table on every nightly run. Those choices make the final task expensive as the 30-night history accumulates.

`dag.sql` improves the execution plan in two ways:

1. **Temporal lookup:** it derives `load_ts` / `next_ts` validity intervals with `LEAD()` and joins each serve to the interval that applies, avoiding the large candidate-ranking step.
2. **Target materialization:** it declares `ad_impressions` incremental with `impression_id` as the merge key and scopes the event input using `event_version`.

The most important fix is the first one: **do not join every impression to every historical account version and rank afterward when the temporal relationship can be represented as non-overlapping validity intervals.** This is why `dag.sql` has a substantially better runtime shape for the full 30-night schedule.

This is a code-level explanation based on the two submitted SQL files and the reported error. It does not claim a fresh hidden-data benchmark; only a rerun on the same practice/full schedule can confirm the actual runtime improvement.
