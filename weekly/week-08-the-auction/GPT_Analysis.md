# Week 8 — The Auction

**Challenge type:** SQL/DAG  
**Repository submission:** `weekly/week-08-the-auction/dag.sql`  
**Reference:** `weekly/week-08-the-auction/gold_submit.sql`  
**Target output:** `ad_impressions`, one row per eligible impression ID  
**Review status:** Approved by the repository owner before creation  
**Evidence basis:** README evaluator summary, Week_8_DOC task contract/sample, current `dag.sql`, and `gold_submit.sql`. No new execution or benchmark is claimed in this report.

## 1. Executive summary

The submission is a five-statement DAG with incremental event/account version and history tasks, followed by an incremental `ad_impressions` task. The reference uses two durable incremental histories, a dedicated `event_norm` task, and a table-materialized final result. The submission has a sensible separation between raw-event normalization, account versioning, histories, and final output, but several key semantics are incomplete: its event key/history strategy can suppress later copies of an existing logical event; its ID and timestamp normalization reject or fail to order documented representations; and its final billing logic does not implement per-click price selection and the account-local month-close verdict rule.

The README reports **score 0.8416, rank #3 of 8 (top 38%)**, 157,679 rows built of 170,216, and 9,254 rows that matched no record (18,508 points lost). The column results were: served_at 83% correct, served_date 83%, billed_micros 85%, slot 87%, clicked 88%, impression_id 93%, and customer_id 93%. The README also reports 12,537 missed values in several impression-level columns. These are evaluator facts; the issue-to-score attribution below is a reasoned diagnosis from the task conditions and SQL comparison, not a measured per-finding score decomposition.

### Impact ranking

| Priority | Issue | Evidence / location | Likely impact | Recommended change |
|---:|---|---|---|---|
| 1 | Event history can discard later replays / copies | `dag.sql` task config and history tasks; compare gold history tasks | Very high: late-arriving or re-sent rows can be lost before reconciliation | Retain load-version identity and use a replay-safe history merge/watermark |
| 2 | Impression ID canonicalization is incomplete | `dag.sql` event_version `normalized` CTE | Very high: serve and click rows for the same impression fail to join | Strip base64 padding, decode URL substitutions, normalize base64url, then validate |
| 3 | Timestamp parser only accepts three numeric widths | `dag.sql` event_version `event_time` CASE | Very high: missed serves and incorrect event ordering / billing verdicts | Carry numeric `event_epoch` and `loaded_epoch` using the full reference parser |
| 4 | Click billing and fraud are impression-wide / oversimplified | `dag.sql` `click_ranked`, `click_agg`, `last_time`, `invalid_flag` | Very high: incorrect click flag and billed amount | Normalize price to micros, select first two priced clicks, then resolve a verdict per click before month close |
| 5 | Slot aliases, event vocabulary, partner/adtest exclusions are incomplete | `dag.sql` event normalization; compare gold `event_norm` | High: missing/incorrect slots and extraneous rows | Use explicit canonical maps and apply eligibility flags before output |
| 6 | Account timezone as-of logic is fragile and account history identity is incomplete | `account_version`, `accounts_history`, `acct_iv` | Medium-high: wrong local day around account changes / DST | Preserve all account snapshots, choose latest version at serve time, apply IANA timezone rules |
| 7 | Final task is incremental although output is a reconciliation over history | `dag.sql` DAG header and `ad_impressions` | Medium-high: existing rows may not be revisited when a late event or account version changes | Recompute impacted impression IDs from changed history, or materialize full final result as the reference does |

## 2. Task contract and evidence

### Target grain and columns

The Week_8_DOC states that the target has exactly one row per `impression_id`; duplicate rows for the same ID are incorrect. The seven columns are:

- `impression_id`: exact 22-character base64 ID, text key.
- `customer_id`: 10-digit account ID, text without dashes.
- `served_at`: UTC instant as ISO-8601 text at seconds precision.
- `served_date`: `YYYY-MM-DD` in the advertiser account's timezone.
- `slot`: nullable enum: `top-1`–`top-4`, `bottom-1`–`bottom-3`.
- `clicked`: integer 1 if any click happened, regardless of a later fraud decision; otherwise 0.
- `billed_micros`: integer sum of the first two priced clicks, in micros; an invalid verdict zeros the applicable click's charge.

The task excludes search-partner ads and `adtest` preview serves. The README specifies a 30-night window from 2026-10-09 through 2026-11-07 and a billing month close of 2026-10-31. The sample in Week_8_DOC contains 12 raw event rows, 28 account rows, and 8 expected output rows. The complete source tables are documented as 285,128 event rows and 14,872 account rows.

### Submission versus reference

| Area | Current submission | Reference design |
|---|---|---|
| Event history | Incremental merge keyed by derived `event_key`; history anti-joins keys already present | History key retains source identity including `_loaded_at`; derives event/load epochs and uses a load-time lookback/watermark |
| Account history | Key combines account attributes and load date; incremental anti-join | Retains account snapshot versions with load epoch |
| Normalization | Combined into `event_version`; 22-character ID check and a limited timestamp CASE | Dedicated `event_norm` with ID, event, timestamp, account, slot, price, adtest and partner normalization |
| Account timezone | `LEAD(load_ts)` validity intervals; first version special-cased | Account version selected as of serve time, with first-known fallback and timezone transition logic |
| Clicks | First two clicks by text event time; integer-only price | First two priced clicks after price parsing and conversion |
| Fraud | Latest event time per impression; any latest invalid event zeros all billing | Latest applicable verdict per click, bounded by that click's account-local month close |
| Final output | Incremental merge by impression ID | Table materialization after normalizing durable histories |

The reference is evidence of a working approach to the stated contract, not proof that every implementation detail must be copied. Preserve the submission's useful task separation where it is semantically safe.

## 3. Findings, ordered by impact

### Finding 1 — History identity and replay handling

**Anchors:** DAG header task definitions; `ad_events_history` and `accounts_history` SQL tasks; compare gold history tasks.

**Code before — current implementation:**

Current event history task:

```sql
WITH merge_incremental AS (
    SELECT d.*
    FROM event_version AS d
    {% if is_incremental() %}
    LEFT JOIN {{ this }} AS x
      ON x.event_key = d.event_key
    WHERE x.event_key IS NULL
    {% endif %}
)
SELECT *
FROM merge_incremental;
```

Current account history task:

```sql
SELECT d.account_key,
       d.customer_id,
       d.time_zone,
       d.currency_code,
       d.load_at,
       d.load_date
FROM account_version AS d
{% if is_incremental() %}
LEFT JOIN {{ this }} AS x
  ON x.account_key = d.account_key
WHERE x.account_key IS NULL
{% endif %};
```

The DAG declares `event_version` and `ad_events_history` unique on `event_key`; account version and history are unique on `account_key`. In `event_version`, the event key is composed from normalized impression ID, category, event time, customer ID and raw detail; `loaded_at` is not part of that key.

**Current behavior:** once a logical event key exists in history, a later source copy with the same normalized fields is filtered out by the anti-join. That loses the newer copy's ingestion timestamp. This matters because the task explicitly describes a day being re-sent under a later stamp, Asia's file arriving after a run has moved its watermark, and a fraud verdict being reprocessed later. A later-loaded replay may be the newest available version even if its event-time fields are unchanged.

**Reference behavior:** the reference history tasks retain source load metadata and derive `loaded_epoch`; their incremental filter is based on a load-time watermark with a replay/lookback boundary, rather than treating the normalized business event key as the only evidence that a row has already been seen. The reference's raw history identity includes `_loaded_at`.

**Concrete scenario:** the same event is copied on two mornings. The event fields are identical, but `_loaded_at` differs. The current derived `event_key` remains identical, so the second copy is excluded. If that later copy represents a reprocessed fraud verdict, the final task cannot observe its later ingestion ordering.

**Code after — proposed change:**

Use the raw source-version identity for history and retain both event and ingestion time. The following is the task-level shape; keep the exact parser expressions from the reference history tasks when implementing the epoch columns.

```sql
-- dag.yml: preserve distinct landed versions
ad_events_history:
  materialized: incremental
  incremental_strategy: merge
  unique_key:
    - impression_id
    - event
    - event_time
    - customer_id
    - detail
    - _loaded_at
  depends_on: [ad_events]

accounts_history:
  materialized: incremental
  incremental_strategy: merge
  unique_key:
    - customer_id
    - _loaded_at
  depends_on: [accounts]
```

```sql
-- History SELECT must retain source version and normalized epoch columns.
SELECT
    impression_id,
    event,
    event_time,
    customer_id,
    detail,
    _loaded_at,
    event_epoch,
    loaded_epoch
FROM parsed_source_versions
WHERE loaded_epoch IS NULL
   OR loaded_epoch >= COALESCE(
       (SELECT MAX(loaded_epoch) FROM {{ this }}),
       0
   );
```

Here `parsed_source_versions` represents the normalization subquery that parses the source timestamps; it is not an existing table in the submission. The exact parsing logic is lengthy and should be taken from the corresponding reference history task rather than replaced with a simplistic cast. Use an overlap/lookback or replay-safe merge when the source can deliver older-stamped files after the current watermark; a strict `>= max(loaded_epoch)` alone is not a universal late-arrival guarantee.

**Root cause and lesson:** the submission conflates a logical event identity with a landed source-version identity. A stable event key is useful for deduplicating identical records, but it must not erase the fact that a source row was delivered again later when load order is part of the task semantics. Keep `event_epoch` (business event time) and `loaded_epoch` (arrival time) separate.

**Trade-off / edge cases:** retaining versions increases history size, but preserves replay and late-arrival evidence. If storage reduction is required, deduplicate only after preserving the latest relevant source version and enough history to resolve verdicts. Test exact duplicate rows with identical `_loaded_at`, same event with later `_loaded_at`, old file arriving after a newer file, and a verdict reissued after an earlier verdict.

### Finding 2 — Impression ID normalization drops valid representations

**Anchor:** `event_version` → `normalized` CTE in `dag.sql`.

**Code before — current implementation:**

```sql
CASE
    WHEN length(impression_id) = 22
     AND regexp_like(impression_id, '^[A-Za-z0-9+/]{22}$')
    THEN impression_id
    ELSE NULL
END AS impression_id
```

**Current behavior:** only a clean 22-character standard-base64 alphabet passes. The README explicitly says 5% of IDs have trailing `=` padding and 45% of click IDs use URL-safe or percent-encoded forms. The Week_8_DOC sample also contains standard IDs with `+` and `/`, so the canonical key must preserve those characters after decoding.

**Reference behavior:** the reference strips BOM/quotes, decodes the relevant percent-encoded characters, removes trailing padding, normalizes the ID alphabet, then validates the 22-character canonical form.

**Worked example:** a serve may contain `A3ov7PHu5IgfPo0Zyfyqzw==`, while a click contains the unpadded canonical ID. If one side is rejected or retained in a different representation, the click cannot be joined to the served ad.

**Code after — proposed change:**

```sql
-- Replace the current impression_id expression in event_version.normalized.
WITH id_step_1 AS (
    SELECT
        replace(
          replace(
            replace(
              replace(trim(impression_id), char(65279), ''),
              '%2B', '+'
            ),
            '%2b', '+'
          ),
          '%2F', '/'
        ) AS id0,
        event, event_time, customer_id, detail, loaded_at
    FROM replace_null
),
id_step_2 AS (
    SELECT
        CASE
          WHEN id0 LIKE '%=' THEN rtrim(id0, '=')
          ELSE id0
        END AS id1,
        event, event_time, customer_id, detail, loaded_at
    FROM id_step_1
),
id_normalized AS (
    SELECT
        CASE
          WHEN substr(id1, 1, 1) = char(34) AND substr(id1, -1) = char(34)
            OR substr(id1, 1, 1) = char(39) AND substr(id1, -1) = char(39)
            THEN substr(id1, 2, length(id1) - 2)
          ELSE id1
        END AS impression_id,
        event, event_time, customer_id, detail, loaded_at
    FROM id_step_2
)
SELECT
    CASE
      WHEN length(impression_id) = 22
       AND NOT regexp_like(impression_id, '[^A-Za-z0-9+/_-]')
      THEN impression_id
      ELSE NULL
    END AS impression_id,
    event, event_time, customer_id, detail, loaded_at
FROM id_normalized;
```

The above illustrates the exact transformation order used by the reference, but the complete implementation must also ensure the URL-encoding policy covers every documented encoded byte and that the accepted alphabet is canonicalized consistently. The reference's `event_norm` performs the full pipeline at its `id0`/`id1`/`iid` steps.

**Expected state:** all equivalent source encodings map to one canonical 22-character ID before event grouping, joining, and final unique-key enforcement. Do not convert the ID to a number; leading characters and case are meaningful.

**Trade-off / edge cases:** normalization adds string operations per raw row, but prevents large downstream misses. Validate trailing one/two padding characters, percent-encoded plus/slash in both hex cases, base64url `-`/`_`, BOM, surrounding quotes, invalid alphabet, NULL and literal-null tokens. Ensure malformed IDs become NULL rather than silently mutating into another valid key.

### Finding 3 — Timestamp parsing and ordering are incomplete

**Anchor:** `event_version` → `normalized` CTE, `event_time` CASE.

**Code before — current implementation:**

```sql
CASE
    WHEN regexp_like(event_time, '^[0-9]{16}$')
      THEN strftime('%Y-%m-%dT%H:%M:%SZ',
                    CAST(event_time AS DOUBLE) / 1000000.0,
                    'unixepoch')
    WHEN regexp_like(event_time, '^[0-9]{13}$')
      THEN strftime('%Y-%m-%dT%H:%M:%SZ',
                    CAST(event_time AS DOUBLE) / 1000.0,
                    'unixepoch')
    WHEN regexp_like(event_time, '^[0-9]{10}$')
      THEN strftime('%Y-%m-%dT%H:%M:%SZ',
                    CAST(event_time AS DOUBLE),
                    'unixepoch')
END AS event_time
```

**Current behavior:** the expression recognizes microseconds, milliseconds and seconds when represented as exactly 16, 13 or 10 digits. It returns NULL for other supported forms. The README describes 18% of times in three other forms, including ISO strings, California local times with an offset, and alternate timestamp encodings. The downstream windows sort `event_time` as text, not a numeric epoch.

**Why it matters:** lexicographic timestamp ordering is not a safe substitute for instant ordering when offsets and formats differ. Incorrect event ordering changes the selected serve, first two clicks, and latest applicable fraud verdict. A NULL serve time also prevents a row from being built.

**Reference behavior:** the gold history task produces both `event_epoch` and `loaded_epoch` with a parser that handles the documented formats. Its `event_norm` then carries those numeric values into the final task.

**Code after — proposed change:**

Use two separate numeric columns in history, preserving the raw source text for traceability:

```sql
-- In event history, expose both parser outputs:
SELECT
    impression_id,
    event,
    event_time,              -- retain raw value for audit
    customer_id,
    detail,
    _loaded_at,
    event_epoch,             -- parsed business instant, UTC epoch seconds
    loaded_epoch             -- parsed ingestion instant, UTC epoch seconds
FROM parsed_event_history;
```

Then rank by numeric time and use a deterministic tie-breaker:

```sql
ROW_NUMBER() OVER (
    PARTITION BY impression_id
    ORDER BY event_epoch, COALESCE(loaded_epoch, 0), event_key
) AS event_order
```

The parser is not safely reducible to the three CASE branches above. Port the full event-time and load-time parsing expressions from the reference history tasks, preserving their documented handling of numeric precision, ISO text, explicit offsets, UTC/GMT suffixes, and malformed values. Keep the raw timestamp and parsed epoch side by side so invalid parses can be counted and investigated.

**Worked example:** the same instant expressed as UTC text and as California local time with its offset must yield the same epoch. Sorting the raw strings can place them in the wrong order; sorting numeric epochs gives the chronological order.

**Trade-off / edge cases:** parsing is CPU work on the raw history stream; doing it once in the durable history/normalization stage avoids repeating complex parsing in every downstream CTE. Test seconds/milliseconds/microseconds, ISO with `Z`, positive and negative offsets, offset without colon, UTC/GMT suffixes, DST overlap/gap, NULL/literal NULL, malformed dates, and equal event times with different load times.

### Finding 4 — Click flag, price parsing and fraud billing do not match the contract

**Anchor:** final `ad_impressions` task, `click_ranked`, `click_agg`, `last_time`, and `invalid_flag`.

**Code before — current implementation:**

```sql
click_ranked AS (
    SELECT impression_id,
           raw_detail,
           ROW_NUMBER() OVER (
               PARTITION BY impression_id
               ORDER BY event_time, event_key
           ) AS rn
    FROM ev
    WHERE event_category = 'click'
),
click_agg AS (
    SELECT impression_id,
           SUM(CASE
                 WHEN regexp_like(raw_detail, '^-?[0-9]+$')
                 THEN CAST(raw_detail AS BIGINT)
                 ELSE 0
               END) AS billed_micros
    FROM click_ranked
    WHERE rn <= 2
    GROUP BY impression_id
),
last_time AS (
    SELECT impression_id, MAX(event_time) AS max_time
    FROM ev
    GROUP BY impression_id
),
invalid_flag AS (
    SELECT DISTINCT e.impression_id
    FROM ev AS e
    INNER JOIN last_time AS l
      ON l.impression_id = e.impression_id
     AND l.max_time = e.event_time
    WHERE e.event_category = 'invalid'
)
```

Final output logic:

```sql
CASE WHEN c.impression_id IS NOT NULL THEN 1 ELSE 0 END AS clicked,
CASE WHEN f.impression_id IS NOT NULL THEN 0
     ELSE COALESCE(c.billed_micros, 0) END AS billed_micros
```

**Current behavior and why it matters:**

1. The first two clicks are selected before checking whether a usable price exists. The task says first two clicks *with a price* are billed.
2. Only integer text is accepted as micros. The README documents prices represented as decimal currency values and other currency formats.
3. The fraud decision is collapsed to one impression-wide flag. The task requires a verdict to apply to a click, not every click on the impression.
4. The latest event time is not constrained by the account-local billing month close. A verdict after close should create a credit in the next month, not rewrite the closed invoice.
5. `clicked` should remain true when a click occurred even if the price is zero or a later fraud verdict invalidates its charge.

**Reference behavior:** the gold normalization task extracts price fields from JSON/text, parses decimal/grouping conventions and converts to integer micros. The final task chooses the first two priced clicks, deduplicates verdict versions, selects the latest verdict within the click's applicable window, and excludes verdicts at/after that click's month close.

**Code after — proposed change:**

The following CTE structure is the replacement design for the current click/fraud CTEs. It assumes `event_norm` has already produced `iid`, `kind`, `epoch`, `loaded_epoch`, and integer `micros`, and that the account-local month-end epoch has been computed for each click.

```sql
-- A click is visible even if its price is zero or unavailable.
clicked AS (
    SELECT DISTINCT e.iid
    FROM event_norm e
    JOIN keep k ON k.iid = e.iid
    WHERE e.kind = 'click'
),

-- Only priced clicks participate in the first-two billing limit.
clicks AS (
    SELECT iid, epoch, micros, loaded_epoch,
           ROW_NUMBER() OVER (
             PARTITION BY iid
             ORDER BY epoch, COALESCE(loaded_epoch, 0), micros
           ) AS rn
    FROM (
        SELECT e.iid,
               COALESCE(e.epoch, k.served_epoch) AS epoch,
               e.micros,
               MAX(e.loaded_epoch) AS loaded_epoch
        FROM event_norm e
        JOIN keep k ON k.iid = e.iid
        WHERE e.kind = 'click'
          AND e.micros IS NOT NULL
        GROUP BY e.iid, COALESCE(e.epoch, k.served_epoch), e.micros
    )
),

-- c2 adds the billing close for the click's account-local month.
c2 AS (
    SELECT c.iid, c.rn, c.micros, c.epoch,
           account_month_end_epoch(c.iid, c.epoch) AS month_end
    FROM clicks c
    WHERE c.rn <= 2
),

-- Resolve duplicate/replayed verdict versions before joining to clicks.
verd AS (
    SELECT iid, epoch, kind, loaded_epoch
    FROM (
        SELECT iid, epoch, kind, loaded_epoch,
               ROW_NUMBER() OVER (
                 PARTITION BY iid, epoch
                 ORDER BY loaded_epoch DESC, kind
               ) AS rn
        FROM (
            SELECT e.iid, e.epoch, e.kind,
                   MAX(e.loaded_epoch) AS loaded_epoch
            FROM event_norm e
            JOIN keep k ON k.iid = e.iid
            WHERE e.kind IN ('valid', 'invalid')
              AND e.epoch IS NOT NULL
            GROUP BY e.iid, e.epoch, e.kind
        )
    )
    WHERE rn = 1
),

bill_src AS (
    SELECT c.iid, c.rn, c.micros, v.kind,
           ROW_NUMBER() OVER (
             PARTITION BY c.iid, c.rn
             ORDER BY v.epoch DESC, v.loaded_epoch DESC, v.kind
           ) AS vrn
    FROM c2 c
    LEFT JOIN verd v
      ON v.iid = c.iid
     AND v.epoch >= c.epoch - 300
     AND v.epoch < c.month_end
),

bill AS (
    SELECT iid,
           CAST(SUM(
             CASE WHEN kind = 'invalid' THEN 0 ELSE micros END
           ) AS INTEGER) AS billed
    FROM bill_src
    WHERE vrn = 1
    GROUP BY iid
)
```

`account_month_end_epoch` above is an explanatory placeholder, not a built-in SQL function. Replace it with the actual account-timezone/month-close logic from the reference's `zones`, `acc`, `serve_z`, and `c2` CTEs, or implement an equivalent tested timezone dimension. The reference contains explicit transition data for the challenge's date range; a fixed UTC offset is not equivalent to an IANA timezone across DST.

The final projection should use `clicked` and `bill` independently:

```sql
CASE WHEN c.iid IS NOT NULL THEN 1 ELSE 0 END AS clicked,
CAST(COALESCE(b.billed, 0) AS INTEGER) AS billed_micros
```

**Worked example:** an impression has a first priced click, a second priced click and a third click. Only the first two priced clicks enter `c2`. If the latest applicable verdict for click 1 is invalid before the account-local month close, click 1 contributes zero; click 2 remains independently billable. A later verdict after close does not change the closed month's billing amount. `clicked` remains 1 because a click happened.

**Trade-offs / edge cases:** the per-click verdict join is more complex than an impression-wide flag and can increase intermediate rows. Restrict both sides to eligible impression IDs and the first two priced clicks before the join. Test zero-priced duplicates, a click without price, two clicks at the same epoch, a third click, verdicts within and outside the 300-second association window, reissued old verdicts, valid-after-invalid, invalid-after-valid, and verdicts on either side of month close.

### Finding 5 — Event vocabulary, slot aliases and exclusion flags are incomplete

**Anchor:** `event_version` → `normalized.event_category` and `raw_detail`; compare gold `event_norm` lines 408–458 and 285–357.

**Code before — current implementation:**

```sql
CASE
  WHEN lower(trim(event)) IN (
    'serve', 'served', 'serving', 'ad_serve', 'ad_served',
    'ad_serving', 'ad_delivery', 'ad_delivered', 'impression',
    'impressions', 'ad_impression', 'ad_impressions', 'display',
    'displayed', 'render', 'rendered', 'ad_render', 'ad_rendered',
    'auction_win', 'auction_won', 'won', 'bid_won'
  ) THEN 'serve'
  WHEN lower(trim(event)) IN (
    'click', 'clicked', 'clicking', 'ad_click', 'ad_clicked',
    'ad_clicks', 'link_click', 'link_clicked', 'tap', 'tapped',
    'ad_tap', 'interaction', 'interacted'
  ) THEN 'click'
  WHEN lower(trim(event)) IN (
    'invalid', 'fraud', 'fraudulent', 'fraud_detected',
    'ad_fraud', 'click_fraud', 'invalid_click', 'invalid_clicks',
    'invalid_traffic', 'ivt', 'sivt', 'givt', 'bot',
    'bot_traffic', 'bot_detected', 'automated_traffic',
    'suspicious', 'suspicious_activity', 'non_human_traffic',
    'spam', 'fake_click', 'fake_impression'
  ) THEN 'invalid'
  WHEN lower(trim(event)) IN (
    'valid', 'verified', 'legitimate', 'accepted', 'approved',
    'qualified', 'genuine'
  ) THEN 'valid'
  ELSE NULL
END AS event_category
```

Slot mapping only recognizes the enumerated top/bottom spellings in the submission. It does not retain `adtest` or `partner` flags in the normalized event rows.

**Current behavior:** event aliases outside the explicit lists become NULL. The README specifically describes `CLICK`, `IVT`, `reinstated`, older serving vocabulary, `ML2`, `mainline-2`, and `B1`. The contract excludes partner-site ads and adtest previews; the current final `serve_account` does not filter either condition.

**Reference behavior:** the reference `event_norm` normalizes a broad event vocabulary, extracts slot/placement from JSON or delimited text, maps legacy mainline/ML/above/below/B aliases, and computes `adtest` and `partner` flags. The final `keep` CTE filters `adtest = 0 AND partner = 0`.

**Code after — proposed change:**

Add the two flags and canonical slot to the normalized event output. The full reference extraction handles JSON and query-string-like details; this minimal core shows the canonical mapping after extracting a normalized slot token:

```sql
CASE
  WHEN slot_tok IN ('top-1','top-2','top-3','top-4',
                    'bottom-1','bottom-2','bottom-3')
    THEN slot_tok
  WHEN en IN ('mainline','ml','above','top')
       AND trim(detail) IN ('1','2','3','4')
    THEN 'top-' || trim(detail)
  WHEN en IN ('bottom','below','bt','btm','bot')
       AND trim(detail) IN ('1','2','3')
    THEN 'bottom-' || trim(detail)
  ELSE NULL
END AS slot
```

```sql
-- Carry these flags through event_norm, aggregate by impression,
-- and apply them in the final eligible-serve CTE.
flags AS (
  SELECT iid,
         MAX(adtest) AS adtest,
         MAX(partner) AS partner
  FROM event_norm
  GROUP BY iid
),
keep AS (
  SELECT s.*
  FROM serve1 s
  LEFT JOIN flags f ON f.iid = s.iid
  WHERE COALESCE(f.adtest, 0) = 0
    AND COALESCE(f.partner, 0) = 0
)
```

Use the reference's JSON/text extraction for `slot_tok`, `adtest`, and `partner`; the snippet above is the downstream canonicalization/filter boundary, not a substitute for parsing nested JSON or all supported aliases.

**Root cause:** the submission treats `detail` mainly as one simple slot or price string. The actual log is a multi-writer free-text/JSON interface, so it must be parsed according to event kind and source vocabulary before downstream aggregation.

**Edge cases:** unknown slots must remain NULL, not be forced into an enum; a click's price detail must not be interpreted as a slot; a partner/adtest flag on any relevant event must exclude the impression according to the contract. Test every documented alias, invalid enum, JSON field, URL/query-style field, and NULL/literal-null marker.

### Finding 6 — Account version and timezone assignment

**Anchors:** `account_version`, `accounts_history`, and final `acct` / `acct_iv` / `serve_account`.

**Code before — current implementation:**

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
    SELECT s.impression_id,
           s.customer_id,
           s.served_at,
           s.detail,
           DATE(TZ_CONVERT(
             s.served_at, 'UTC', COALESCE(a.time_zone, 'UTC')
           ))::date AS served_date
    FROM serve AS s
    LEFT JOIN acct_iv AS a
      ON a.customer_id = s.customer_id
     AND (a.vn = 1 OR a.load_ts <= s.served_ts)
     AND (a.next_ts IS NULL OR s.served_ts < a.next_ts)
)
```

**Current behavior:** account snapshots are converted into intervals, and the first version is allowed to cover serves before its first load. This is a reasonable as-of pattern, but the submission's `account_key` includes account attributes and `load_date`, while history only anti-joins that key. Multiple same-day snapshots or timezone changes may collapse or be ambiguously ordered if their key does not preserve the original load timestamp. The final timezone conversion also needs to use the account version effective at the serve instant and apply IANA transitions, not a fixed offset.

**Reference behavior:** the gold solution preserves `_loaded_at`/ `loaded_epoch`, normalizes customer IDs, chooses the latest account snapshot available at the serve instant, and uses timezone transition data for the challenge period. It also has a first-known-account fallback where the task requires it.

**Code after — proposed change:**

Preserve the raw account snapshot version and select the latest version no later than the serve instant:

```sql
account_asof AS (
  SELECT impression_id, customer_id, time_zone
  FROM (
    SELECT s.impression_id,
           s.customer_id,
           a.time_zone,
           ROW_NUMBER() OVER (
             PARTITION BY s.impression_id
             ORDER BY a.loaded_epoch DESC, a._loaded_at DESC
           ) AS rn
    FROM serve s
    LEFT JOIN accounts_history a
      ON normalize_account_id(a.customer_id) = s.customer_id
     AND a.loaded_epoch <= s.served_epoch
  )
  WHERE rn = 1
)
```

`normalize_account_id` is a placeholder for the same explicit account-ID normalization CTE used in the gold solution; do not create a user-defined function unless the execution contract permits it. If no account snapshot exists before the serve, apply the task's documented first-known fallback rather than silently inventing a timezone. Convert the instant with the selected IANA timezone using the engine-supported timezone mechanism or the challenge-period transition table.

**Trade-off / edge cases:** keeping all snapshots increases history size but is necessary for accounts that close, open mid-month, or move east. Test leading-zero IDs, dashed IDs, same-day multiple snapshots, timezone change, account closure, account opening, missing account table on a run, DST transition, and serve before the first observed account snapshot.

### Finding 7 — Incremental final output must revisit impacted IDs

**Anchor:** DAG header `ad_impressions` config and final task `ev` filter.

**Code before — current implementation:**

```yaml
ad_impressions:
  materialized: incremental
  depends_on: [ad_events_history, accounts_history, event_version]
  incremental_strategy: merge
  unique_key:
    - impression_id
```

```sql
FROM ad_events_history
WHERE impression_id IS NOT NULL
{% if is_incremental() %}
  AND impression_id IN (
      SELECT impression_id
      FROM event_version
      WHERE impression_id IS NOT NULL
  )
{% endif %}
```

**Current behavior:** the incremental final task scopes recomputation to IDs visible in the current `event_version`. That is directionally useful for changed events, but account-history changes can affect `served_date` without a corresponding event-version row. Also, if the upstream version task filters a re-sent event out, the final task cannot discover the affected ID.

**Reference behavior:** the reference final result is table-materialized from the durable histories, so it recomputes the target from the retained source state. This avoids relying on a narrow event-only change set for account-dependent output.

**Code after — proposed change:**

For the safest reference-aligned behavior, materialize `ad_impressions` as a table and depend on normalized events plus account history:

```yaml
event_norm:
  materialized: table
  depends_on: [ad_events_history, accounts_history]

ad_impressions:
  materialized: table
  depends_on: [event_norm, accounts_history]
```

If incremental materialization is required for cost reasons, build an explicit impacted-ID set from both changed event IDs and IDs whose account version/timezone changed, include a lookback for late-arriving files/verdicts, and merge the recomputed complete row by `impression_id`. Do not use only `event_version` as the change detector.

**Performance note:** full recomputation reads the bounded history and may cost more than an incremental merge. The README reports work per raw row of 1.7x median for the submission, but it does not provide query plans or a benchmark of the alternative; no performance claim beyond that measurement is made here.

## 4. Root-cause chain and expected output behavior

The main failure chain is:

1. Raw event/account snapshots arrive with different timestamp formats, IDs and load times.
2. The current event normalizer rejects padded/encoded IDs and unsupported timestamps.
3. The derived event key does not preserve a later landed version of an otherwise identical logical event.
4. The final task therefore sees incomplete or stale history for some impressions.
5. It chooses the first two raw clicks rather than the first two priced clicks and sums only integer-looking values.
6. It applies a single impression-level latest-invalid flag rather than a click-level verdict bounded by the account-local invoice close.
7. It does not apply partner/adtest exclusions and has incomplete legacy slot mapping.

A successful target row should remain one row per canonical impression ID. For an eligible serve, the output should retain the canonical text ID and 10-digit text customer ID, UTC served instant, account-local calendar date, nullable canonical slot, click-presence flag, and total charge for the first two priced clicks after applicable fraud decisions. A fraud decision changes billed amount, not whether the ad was clicked.

## 5. Validation checklist

### Facts already available (not new tests)

- README evaluator score/rank and row/column measurements.
- Week_8_DOC target schema, constraints, 12-row event sample, 28-row account sample, and 8 expected output rows.
- Static comparison of `dag.sql` and `gold_submit.sql`.
- Existing PostgreSQL companion file is present at `GPT_gold_submit_Postgres.sql`; it was committed separately. It is a SQL translation only and does not implement the DAG runner's scheduling/materialization.

### Tests / queries to execute

The following are proposed checks. They were **not executed** as part of this report.

1. **Target grain / duplicates**
   ```sql
   SELECT impression_id, COUNT(*) AS n
   FROM ad_impressions
   GROUP BY impression_id
   HAVING COUNT(*) <> 1;
   ```
   Expected: zero rows.

2. **Required NULLs**
   ```sql
   SELECT
     SUM(CASE WHEN impression_id IS NULL THEN 1 ELSE 0 END) AS null_ids,
     SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_customers,
     SUM(CASE WHEN served_at IS NULL THEN 1 ELSE 0 END) AS null_served_at,
     SUM(CASE WHEN served_date IS NULL THEN 1 ELSE 0 END) AS null_served_date
   FROM ad_impressions;
   ```
   Expected: all zero, subject to the exact target contract.

3. **Slot domain**
   ```sql
   SELECT slot, COUNT(*)
   FROM ad_impressions
   WHERE slot IS NOT NULL
     AND slot NOT IN ('top-1','top-2','top-3','top-4',
                      'bottom-1','bottom-2','bottom-3')
   GROUP BY slot;
   ```
   Expected: zero rows.

4. **Date boundaries**
   Check serves immediately before/after UTC midnight and local midnight for each timezone represented in the sample; include DST transition dates and the inclusive 2026-10-09 / exclusive 2026-11-08 UTC window.

5. **ID normalization**
   Compare canonical IDs from serve and click records after padding removal, percent-decoding and base64url normalization. Count malformed IDs separately from valid-but-unmatched IDs.

6. **Price and click semantics**
   For each impression, compare click-presence with existence of any click; separately verify that only the first two priced clicks contribute to `billed_micros`. Include integer micros, decimal currency, zero-price duplicate, missing price and third-click cases.

7. **Fraud reconciliation**
   For every billed click, verify the latest applicable verdict by event time and load version, limited to the 300-second association window and strictly before account-local month close. Include verdict replay, valid-after-invalid, invalid-after-valid and post-close verdict.

8. **Partner / adtest**
   Assert no output impression has a positive partner or adtest flag.

9. **History replay / late arrivals**
   Load the same source row twice with identical load time; load the same logical event under a later load time; then load an older file after a newer watermark. Verify deduplication and retention match the task's version semantics.

10. **Account reconciliation**
    Compare normalized account IDs and effective account timezone at serve time, including dashed IDs, leading zero, account open/close, account timezone move and DST transition.

11. **Sample-output reconciliation**
    Run the Week_8_DOC sample and compare all 8 expected rows and all 7 columns, including strict types and NULLs.

### Execution status

No SQL engine execution, DAG run, PostgreSQL run, query-plan inspection, or sample-output comparison was performed for this report. The checks above are proposed validation steps only. Do not interpret the README evaluator result as proof that any particular proposed change has been tested.

## 6. Reusable lessons

1. Keep **business event time** and **ingestion/load time** as separate columns. They answer different questions.
2. Normalize identifiers before grouping, joining, and enforcing uniqueness. Never numeric-cast identifiers whose leading zeros or alphabet are meaningful.
3. Build a canonical event model at the boundary between raw multi-writer logs and business logic. Event vocabulary, timestamps, IDs, slots, prices, and flags should be normalized once.
4. Select the first N *eligible* events only after defining eligibility. “First two clicks” and “first two priced clicks” are not equivalent.
5. Apply fraud or status decisions at the grain where the contract defines them. An impression-level flag can incorrectly affect multiple clicks.
6. Use account-local calendar boundaries for billing. UTC date truncation and fixed offsets fail around timezone changes.
7. Incremental pipelines need explicit late-arrival and replay semantics. A unique key alone does not prove that a later source copy is irrelevant.
8. Recompute every output key affected by any upstream dependency, not just the most obvious event stream.
9. Use the gold solution as a behavioral reference, but explain why each transformation is needed from the task contract and sample.
10. Separate SQL correctness from DAG orchestration. PostgreSQL compatibility of a query does not make the original DAG scheduling/materialization configuration executable in PostgreSQL.

## 7. Source references

- `README.md`: score/rank, evaluator row/column outcomes, challenge conditions, schedule and task summary.
- `Week_8_DOC.md`: source schemas, sample rows, exact target grain/schema, expected 8-row sample output and scoring rules.
- `dag.sql`: submitted DAG configuration and SQL task definitions.
- `gold_submit.sql`: reference history, normalization, timezone, eligibility, click and fraud logic.
- `GPT_gold_submit_Postgres.sql`: existing PostgreSQL companion translation; no change made to it in this analysis commit.

**Conclusion:** the highest-value improvements are replay-safe history, canonical ID/time normalization, and click-level billing/fraud reconciliation. These changes should be implemented and validated against the sample and edge cases before claiming a score improvement.
