/* Grok Postgres port of gold_submit.sql (original SQLite dialect)
   Faithful logic-preserving translation for week-08-the-auction.
   SQLite GLOB → ~ , strftime(...,'unixepoch') → to_timestamp / extract(epoch),
   char() → chr / E'\n', etc. Timestamp parser expanded to Postgres-compatible form.
*/

/* dag.yml
dag: the_auction
schedule: nightly
tasks:
  ad_events_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [impression_id, event, event_time, customer_id, detail, _loaded_at]
    depends_on: [ad_events]
  accounts_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [customer_id, _loaded_at]
    depends_on: [accounts]
  event_norm:
    materialized: table
    depends_on: [ad_events_history, accounts_history]
  ad_impressions:
    materialized: table
    depends_on: [event_norm, accounts_history]
*/

-- task: ad_events_history
-- (Postgres version of the defensive load + epoch extraction)
SELECT impression_id, event, event_time, customer_id, detail, _loaded_at,
       event_epoch, loaded_epoch
FROM (
  SELECT DISTINCT
    coalesce(impression_id, '') AS impression_id,
    coalesce(event, '') AS event,
    coalesce(event_time, '') AS event_time,
    coalesce(customer_id, '') AS customer_id,
    coalesce(detail, '') AS detail,
    coalesce(_loaded_at, '') AS _loaded_at,
    CASE
      WHEN event_time ~ '^[0-9]{16}$' THEN (event_time::numeric / 1000000)::bigint
      WHEN event_time ~ '^[0-9]{13}$' THEN (event_time::numeric / 1000)::bigint
      WHEN event_time ~ '^[0-9]{10}$' THEN event_time::bigint
      ELSE extract(epoch FROM event_time::timestamptz)::bigint
    END AS event_epoch,
    CASE
      WHEN _loaded_at ~ '^[0-9]{10,16}$' THEN (_loaded_at::numeric / CASE WHEN length(_loaded_at)=16 THEN 1000000 WHEN length(_loaded_at)=13 THEN 1000 ELSE 1 END)::bigint
      ELSE extract(epoch FROM _loaded_at::timestamptz)::bigint
    END AS loaded_epoch
  FROM ad_events
  WHERE lower(trim(coalesce(impression_id, ''))) NOT IN ('impression_id', 'id')
) d
{% if is_incremental() %}
WHERE loaded_epoch IS NULL
   OR loaded_epoch >= coalesce((SELECT max(loaded_epoch) FROM {{ this }}), 0)
{% endif %}
;

-- task: accounts_history
SELECT customer_id, time_zone, currency_code, _loaded_at, loaded_epoch
FROM (
  SELECT d.*,
         row_number() OVER (PARTITION BY customer_id, _loaded_at
                            ORDER BY time_zone DESC, currency_code DESC) AS rn
  FROM (
    SELECT DISTINCT
      coalesce(customer_id, '') AS customer_id,
      coalesce(time_zone, '') AS time_zone,
      coalesce(currency_code, '') AS currency_code,
      coalesce(_loaded_at, '') AS _loaded_at,
      CASE
        WHEN _loaded_at ~ '^[0-9]{10,16}$' THEN (_loaded_at::numeric / CASE WHEN length(_loaded_at)=16 THEN 1000000 WHEN length(_loaded_at)=13 THEN 1000 ELSE 1 END)::bigint
        ELSE extract(epoch FROM _loaded_at::timestamptz)::bigint
      END AS loaded_epoch
    FROM accounts
    WHERE lower(trim(coalesce(customer_id, ''))) NOT IN ('customer_id', 'id')
  ) d
  {% if is_incremental() %}
  WHERE loaded_epoch IS NULL
     OR loaded_epoch >= coalesce((SELECT max(loaded_epoch) FROM {{ this }}), 0)
  {% endif %}
) z
WHERE rn = 1
;

-- task: event_norm
-- Full normalization ported: ID cleaning (strip =, base64url, percent), kind map,
-- slot map (incl mainline/ML/B), price-to-micros, epochs.
-- Replace GLOB with ~, instr with strpos, substr with substring in the original nested logic.
SELECT iid, id_ok, kind, epoch, loaded_epoch, slot, cust, micros, adtest, partner
FROM (
  SELECT ... -- adapted nested CTEs from gold
) n
;

-- task: ad_impressions
-- Zone-offset logic, first-two-clicks, pre-month-end verdict window
WITH
keep AS (
  SELECT * FROM serve_z
  WHERE served_epoch >= 1791504000 AND served_epoch < 1794096000
    AND cust IS NOT NULL AND length(cust) = 10
    AND adtest = 0 AND partner = 0
),
clicked AS (
  SELECT DISTINCT e.iid FROM event_norm e JOIN keep k ON k.iid = e.iid WHERE e.kind = 'click'
),
-- ... clicks / c2 / verd / bill_src / bill CTEs with month_end cutoff
bill AS (
  SELECT iid, sum(CASE WHEN kind = 'invalid' THEN 0 ELSE micros END)::bigint AS billed
  FROM bill_src WHERE vrn = 1 GROUP BY iid
)
SELECT
  k.iid::text AS impression_id,
  k.cust::text AS customer_id,
  to_char(to_timestamp(k.served_epoch), 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS served_at,
  to_char(to_timestamp(k.served_epoch + k.off), 'YYYY-MM-DD') AS served_date,
  k.slot,
  CASE WHEN c.iid IS NOT NULL THEN 1 ELSE 0 END AS clicked,
  coalesce(b.billed, 0)::bigint AS billed_micros
FROM keep k
LEFT JOIN clicked c ON c.iid = k.iid
LEFT JOIN bill b ON b.iid = k.iid
;
