# Week 8 – Why `dag.sql` finishes but `captime_error_submit.sql` hits the 1-minute practice cap

**Error observed**
```
Your code ran past the 1m practice cap · stopped at task ad_impressions
5m 38s/10m
```

The schedule runs for 30 nights. The practice environment enforces a **1-minute wall-clock limit per task**. The full 10-minute schedule cap is a separate gate. The failing submission dies on the `ad_impressions` task once the history has grown large enough.

---

## 1. The decisive difference: materialization strategy of `ad_impressions`

### `captime_error_submit.sql` (fails)

```yaml
ad_impressions:
  materialized: table                    # ← full rebuild every night
  depends_on: [ad_events_history, accounts_history]
```

and inside the query:

```sql
WITH ev AS (
    SELECT ...
    FROM ad_events_history               -- always the whole history
    WHERE impression_id IS NOT NULL
),
```

Every night the engine:

1. Drops / truncates the previous `ad_impressions` table.
2. Re-scans the **entire** accumulated `ad_events_history`.
3. Recomputes every serve / click / invalid flag / account interval for every impression ever seen.

By night ~15–20 the history is already large. The query starts taking > 60 s and the practice cap kills it.

### `dag.sql` (passes)

```yaml
ad_impressions:
  materialized: incremental
  depends_on: [ad_events_history, accounts_history, event_version]
  incremental_strategy: merge
  unique_key:
    - impression_id
```

and the critical filter:

```sql
WITH ev AS (
    SELECT impression_id, event_key, event_category,
           event_time, customer_id, raw_detail
    FROM ad_events_history
    WHERE impression_id IS NOT NULL
    {% if is_incremental() %}
      AND impression_id IN (
            SELECT impression_id
            FROM event_version
            WHERE impression_id IS NOT NULL
          )
    {% endif %}
),
```

Only the impression_ids that appear in the **current night’s** `event_version` are processed. Everything else is left untouched in the already-materialized incremental table. Runtime stays roughly constant across all 30 nights.

---

## 2. Secondary performance differences

| Aspect                        | `captime_error_submit.sql`                          | `dag.sql`                                      | Effect                                      |
|-------------------------------|-----------------------------------------------------|------------------------------------------------|---------------------------------------------|
| Account matching              | Cross every serve × every account version, then `ROW_NUMBER()` | Validity intervals with `LEAD`                 | Cheaper join + no ranking of all pairs      |
| Depends on `event_version`    | No                                                  | Yes                                            | Enables the incremental filter above        |
| History tables                | Incremental (good)                                  | Incremental (good)                             | Same                                        |
| Final SELECT complexity       | Similar                                             | Similar                                        | Not the main cause                          |

The account-matching rewrite in `dag.sql` is nicer and a bit faster, but it is **not** the reason the job dies. Even with a perfect account join, a full-history rebuild every night will eventually exceed the 1-minute practice limit.

---

## 3. Why the history grows and why that matters

- `ad_events` retains only the last **three** nights of raw data.
- The pipeline deliberately keeps a long-lived history (`ad_events_history`, `accounts_history`) via incremental merges so that late-arriving clicks, late fraud verdicts, and accounts that have already closed can still be joined correctly.
- That design is correct for correctness, but it means any task declared as `materialized: table` that reads the whole history will get slower every night.

Only the combination of:

1. `materialized: incremental` + unique key, **and**
2. an explicit filter that restricts work to the new keys of the current night

keeps the per-night cost of `ad_impressions` under the 1-minute practice ceiling for all 30 nights.

---

## 4. Summary – what to remember for future weeks

- Prefer `materialized: incremental` (with a sensible unique key) for any task that must look at growing history.
- Always add a filter of the form  
  `AND <key> IN (SELECT <key> FROM <current_version_task>)`  
  inside the incremental block so that only new business keys are re-processed.
- Full-table rebuilds (`materialized: table`) are fine only when the input is bounded (e.g. a single night of raw data) or the data volume is known to stay tiny.

That is the entire reason `dag.sql` finishes the schedule while `captime_error_submit.sql` is killed on `ad_impressions`.
