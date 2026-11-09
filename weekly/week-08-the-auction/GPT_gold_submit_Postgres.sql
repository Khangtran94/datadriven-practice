/* PostgreSQL companion translation for Week 8 — The Auction.
   Source of truth: gold_submit.sql (SQLite dialect). Do not replace the source.
   Target: PostgreSQL 16+; pg_input_is_valid(text, 'jsonb') is used to guard
   JSON parsing. This is query SQL only: DAG scheduling, incremental merge,
   task materialization, and dependency orchestration remain with the runner.
   Set the session time zone to UTC so naive source timestamp strings retain
   their intended UTC interpretation.
   Validation: static-only in this run. No PostgreSQL execution or comparison
   against the 8-row sample output was performed. Validate before production.
*/
SET TIME ZONE 'UTC';

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
 
SELECT impression_id, event, event_time, customer_id, detail, _loaded_at, event_epoch, loaded_epoch
FROM (
  
SELECT DISTINCT coalesce(impression_id, '') AS impression_id, coalesce(event, '') AS event, coalesce(event_time, '') AS event_time, coalesce(customer_id, '') AS customer_id, coalesce(detail, '') AS detail, coalesce(_loaded_at, '') AS _loaded_at,
       (
  SELECT CASE
    WHEN t = '' OR lower(t) IN ('', chr(92)||'n', chr(92)||chr(92)||'n', 'null', 'none', 'nan', 'n/a', 'na', '-', 'undefined', 'nil', '(null)', 'n.a.', 'n.a') THEN NULL
    WHEN (ip ~ '^[0-9].*$') AND NOT (ip ~ '^.*[^0-9].*$') AND length(ip) BETWEEN 8 AND 19 THEN
      CASE
        WHEN length(ip) = 14 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2)||' '||
          substr(ip,9,2)||':'||substr(ip,11,2)||':'||substr(ip,13,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) = 8 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) >= 18 THEN CAST(substr(ip, 1, length(ip) - 9) AS INTEGER)
        WHEN length(ip) >= 15 THEN CAST(substr(ip, 1, length(ip) - 6) AS INTEGER)
        WHEN length(ip) >= 12 THEN CAST(substr(ip, 1, length(ip) - 3) AS INTEGER)
        WHEN length(ip) >= 9 THEN CAST(ip AS INTEGER)
      END
    WHEN length(ip) - length(replace(ip, '.', '')) = 1
     AND NOT (replace(ip, '.', '') ~ '^.*[^0-9].*$') THEN
      CASE
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 18
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 9) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 15
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 6) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 12
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 3) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 9
          THEN CAST(substr(ip, 1, strpos(ip, '.') - 1) AS INTEGER)
      END
    WHEN strpos(lower(ip), 'e') > 0 AND NOT (lower(ip) ~ '^.*[^0-9.e+-].*$') THEN
      CASE
        WHEN CAST(ip AS REAL) >= 1e18 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000000
        WHEN CAST(ip AS REAL) >= 1e15 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000
        WHEN CAST(ip AS REAL) >= 1e12 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000
        WHEN CAST(ip AS REAL) >= 1e9 THEN CAST(CAST(ip AS REAL) AS INTEGER)
      END
    ELSE CAST((extract(epoch FROM (norm)::timestamptz)::bigint) AS INTEGER)
  END
  FROM (
    SELECT t, ip,
      CASE
        WHEN (base ~ '^.*[+-][0-9][0-9]$') AND NOT (base ~ '^.*[+-][0-9][0-9]:[0-9][0-9]$')
          THEN base || ':00'
        WHEN (base ~ '^.*[+-][0-9][0-9][0-9][0-9]$') AND NOT (base ~ '^.*:.*$')
          THEN substr(base, 1, length(base) - 2) || ':' || substr(base, -2)
        ELSE base
      END AS norm
    FROM (
      SELECT t, ip,
        CASE
          WHEN substr(cut, 11, 1) IN ('T', 't') THEN substr(cut, 1, 10) || ' ' || substr(cut, 12)
          ELSE cut
        END AS base
      FROM (
        SELECT t, ip,
          CASE
            WHEN (t ~ '^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9].*$') THEN replace(t, '/', '-')
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
                 AND CAST(substr(t, 1, 2) AS INTEGER) > 12
              THEN substr(t,7,4)||'-'||substr(t,4,2)||'-'||substr(t,1,2)||substr(t,11)
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
              THEN substr(t,7,4)||'-'||substr(t,1,2)||'-'||substr(t,4,2)||substr(t,11)
            WHEN lower(t) LIKE '% utc' THEN substr(t, 1, length(t) - 4)
            WHEN lower(t) LIKE '% gmt' THEN substr(t, 1, length(t) - 4)
            WHEN lower(substr(t, -1)) = 'z' AND (substr(t, -2, 1) ~ '^[0-9]$')
              THEN substr(t, 1, length(t) - 1)
            ELSE t
          END AS cut
        FROM (
          SELECT trim(coalesce(event_time, '')) AS t,
                 replace(replace(trim(coalesce(event_time, '')), ' ', ''), ',', '') AS ip
        )
      )
    )
  )
) AS event_epoch,
       (
  SELECT CASE
    WHEN t = '' OR lower(t) IN ('', chr(92)||'n', chr(92)||chr(92)||'n', 'null', 'none', 'nan', 'n/a', 'na', '-', 'undefined', 'nil', '(null)', 'n.a.', 'n.a') THEN NULL
    WHEN (ip ~ '^[0-9].*$') AND NOT (ip ~ '^.*[^0-9].*$') AND length(ip) BETWEEN 8 AND 19 THEN
      CASE
        WHEN length(ip) = 14 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2)||' '||
          substr(ip,9,2)||':'||substr(ip,11,2)||':'||substr(ip,13,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) = 8 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) >= 18 THEN CAST(substr(ip, 1, length(ip) - 9) AS INTEGER)
        WHEN length(ip) >= 15 THEN CAST(substr(ip, 1, length(ip) - 6) AS INTEGER)
        WHEN length(ip) >= 12 THEN CAST(substr(ip, 1, length(ip) - 3) AS INTEGER)
        WHEN length(ip) >= 9 THEN CAST(ip AS INTEGER)
      END
    WHEN length(ip) - length(replace(ip, '.', '')) = 1
     AND NOT (replace(ip, '.', '') ~ '^.*[^0-9].*$') THEN
      CASE
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 18
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 9) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 15
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 6) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 12
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 3) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 9
          THEN CAST(substr(ip, 1, strpos(ip, '.') - 1) AS INTEGER)
      END
    WHEN strpos(lower(ip), 'e') > 0 AND NOT (lower(ip) ~ '^.*[^0-9.e+-].*$') THEN
      CASE
        WHEN CAST(ip AS REAL) >= 1e18 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000000
        WHEN CAST(ip AS REAL) >= 1e15 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000
        WHEN CAST(ip AS REAL) >= 1e12 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000
        WHEN CAST(ip AS REAL) >= 1e9 THEN CAST(CAST(ip AS REAL) AS INTEGER)
      END
    ELSE CAST((extract(epoch FROM (norm)::timestamptz)::bigint) AS INTEGER)
  END
  FROM (
    SELECT t, ip,
      CASE
        WHEN (base ~ '^.*[+-][0-9][0-9]$') AND NOT (base ~ '^.*[+-][0-9][0-9]:[0-9][0-9]$')
          THEN base || ':00'
        WHEN (base ~ '^.*[+-][0-9][0-9][0-9][0-9]$') AND NOT (base ~ '^.*:.*$')
          THEN substr(base, 1, length(base) - 2) || ':' || substr(base, -2)
        ELSE base
      END AS norm
    FROM (
      SELECT t, ip,
        CASE
          WHEN substr(cut, 11, 1) IN ('T', 't') THEN substr(cut, 1, 10) || ' ' || substr(cut, 12)
          ELSE cut
        END AS base
      FROM (
        SELECT t, ip,
          CASE
            WHEN (t ~ '^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9].*$') THEN replace(t, '/', '-')
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
                 AND CAST(substr(t, 1, 2) AS INTEGER) > 12
              THEN substr(t,7,4)||'-'||substr(t,4,2)||'-'||substr(t,1,2)||substr(t,11)
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
              THEN substr(t,7,4)||'-'||substr(t,1,2)||'-'||substr(t,4,2)||substr(t,11)
            WHEN lower(t) LIKE '% utc' THEN substr(t, 1, length(t) - 4)
            WHEN lower(t) LIKE '% gmt' THEN substr(t, 1, length(t) - 4)
            WHEN lower(substr(t, -1)) = 'z' AND (substr(t, -2, 1) ~ '^[0-9]$')
              THEN substr(t, 1, length(t) - 1)
            ELSE t
          END AS cut
        FROM (
          SELECT trim(coalesce(_loaded_at, '')) AS t,
                 replace(replace(trim(coalesce(_loaded_at, '')), ' ', ''), ',', '') AS ip
        )
      )
    )
  )
) AS loaded_epoch
FROM ad_events
WHERE lower(trim(coalesce(impression_id, ''))) NOT IN ('impression_id', 'id')
 
) d
 
{% if is_incremental() %}
WHERE loaded_epoch IS NULL
   OR loaded_epoch >= coalesce((SELECT max(loaded_epoch) FROM {{ this }}), 0)
{% endif %}
 
 
 
-- task: accounts_history
 
SELECT customer_id, time_zone, currency_code, _loaded_at, loaded_epoch
FROM (
  SELECT d.*, row_number() OVER (PARTITION BY customer_id, _loaded_at ORDER BY time_zone DESC, currency_code DESC) AS rn
  FROM (
    
SELECT DISTINCT coalesce(customer_id, '') AS customer_id, coalesce(time_zone, '') AS time_zone, coalesce(currency_code, '') AS currency_code, coalesce(_loaded_at, '') AS _loaded_at,
       (
  SELECT CASE
    WHEN t = '' OR lower(t) IN ('', chr(92)||'n', chr(92)||chr(92)||'n', 'null', 'none', 'nan', 'n/a', 'na', '-', 'undefined', 'nil', '(null)', 'n.a.', 'n.a') THEN NULL
    WHEN (ip ~ '^[0-9].*$') AND NOT (ip ~ '^.*[^0-9].*$') AND length(ip) BETWEEN 8 AND 19 THEN
      CASE
        WHEN length(ip) = 14 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2)||' '||
          substr(ip,9,2)||':'||substr(ip,11,2)||':'||substr(ip,13,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) = 8 AND substr(ip, 1, 2) = '20' THEN CAST((extract(epoch FROM (substr(ip,1,4)||'-'||substr(ip,5,2)||'-'||substr(ip,7,2))::timestamptz)::bigint) AS INTEGER)
        WHEN length(ip) >= 18 THEN CAST(substr(ip, 1, length(ip) - 9) AS INTEGER)
        WHEN length(ip) >= 15 THEN CAST(substr(ip, 1, length(ip) - 6) AS INTEGER)
        WHEN length(ip) >= 12 THEN CAST(substr(ip, 1, length(ip) - 3) AS INTEGER)
        WHEN length(ip) >= 9 THEN CAST(ip AS INTEGER)
      END
    WHEN length(ip) - length(replace(ip, '.', '')) = 1
     AND NOT (replace(ip, '.', '') ~ '^.*[^0-9].*$') THEN
      CASE
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 18
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 9) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 15
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 6) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 12
          THEN CAST(substr(substr(ip, 1, strpos(ip, '.') - 1), 1, length(substr(ip, 1, strpos(ip, '.') - 1)) - 3) AS INTEGER)
        WHEN length(substr(ip, 1, strpos(ip, '.') - 1)) >= 9
          THEN CAST(substr(ip, 1, strpos(ip, '.') - 1) AS INTEGER)
      END
    WHEN strpos(lower(ip), 'e') > 0 AND NOT (lower(ip) ~ '^.*[^0-9.e+-].*$') THEN
      CASE
        WHEN CAST(ip AS REAL) >= 1e18 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000000
        WHEN CAST(ip AS REAL) >= 1e15 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000000
        WHEN CAST(ip AS REAL) >= 1e12 THEN CAST(CAST(ip AS REAL) AS INTEGER) / 1000
        WHEN CAST(ip AS REAL) >= 1e9 THEN CAST(CAST(ip AS REAL) AS INTEGER)
      END
    ELSE CAST((extract(epoch FROM (norm)::timestamptz)::bigint) AS INTEGER)
  END
  FROM (
    SELECT t, ip,
      CASE
        WHEN (base ~ '^.*[+-][0-9][0-9]$') AND NOT (base ~ '^.*[+-][0-9][0-9]:[0-9][0-9]$')
          THEN base || ':00'
        WHEN (base ~ '^.*[+-][0-9][0-9][0-9][0-9]$') AND NOT (base ~ '^.*:.*$')
          THEN substr(base, 1, length(base) - 2) || ':' || substr(base, -2)
        ELSE base
      END AS norm
    FROM (
      SELECT t, ip,
        CASE
          WHEN substr(cut, 11, 1) IN ('T', 't') THEN substr(cut, 1, 10) || ' ' || substr(cut, 12)
          ELSE cut
        END AS base
      FROM (
        SELECT t, ip,
          CASE
            WHEN (t ~ '^[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9].*$') THEN replace(t, '/', '-')
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
                 AND CAST(substr(t, 1, 2) AS INTEGER) > 12
              THEN substr(t,7,4)||'-'||substr(t,4,2)||'-'||substr(t,1,2)||substr(t,11)
            WHEN (t ~ '^[0-9][0-9]/[0-9][0-9]/[0-9][0-9][0-9][0-9].*$')
              THEN substr(t,7,4)||'-'||substr(t,1,2)||'-'||substr(t,4,2)||substr(t,11)
            WHEN lower(t) LIKE '% utc' THEN substr(t, 1, length(t) - 4)
            WHEN lower(t) LIKE '% gmt' THEN substr(t, 1, length(t) - 4)
            WHEN lower(substr(t, -1)) = 'z' AND (substr(t, -2, 1) ~ '^[0-9]$')
              THEN substr(t, 1, length(t) - 1)
            ELSE t
          END AS cut
        FROM (
          SELECT trim(coalesce(_loaded_at, '')) AS t,
                 replace(replace(trim(coalesce(_loaded_at, '')), ' ', ''), ',', '') AS ip
        )
      )
    )
  )
) AS loaded_epoch
FROM accounts
WHERE lower(trim(coalesce(customer_id, ''))) NOT IN ('customer_id', 'id')
 
  ) d
  
{% if is_incremental() %}
WHERE loaded_epoch IS NULL
   OR loaded_epoch >= coalesce((SELECT max(loaded_epoch) FROM {{ this }}), 0)
{% endif %}
 
) z
WHERE rn = 1
 
 
-- task: event_norm
 
SELECT iid, id_ok, kind, epoch, loaded_epoch, slot, cust, micros, adtest, partner
FROM (
  SELECT iid, id_ok, kind, epoch, loaded_epoch, adtest, partner,
    CASE
      WHEN slot_tok IS NOT NULL THEN slot_tok
      WHEN en IN ('mainline', 'ml', 'above', 'top') AND (trim(coalesce(detail, '')) ~ '^[1-4]$')
        THEN 'top-' || trim(detail)
      WHEN en IN ('bottom', 'below', 'bt', 'btm', 'bot') AND (trim(coalesce(detail, '')) ~ '^[1-3]$')
        THEN 'bottom-' || trim(detail)
    END AS slot,
    CASE
      WHEN cdig <> '' AND length(cdig) BETWEEN 1 AND 13
       AND length(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(
             cdig,'0',''),'1',''),'2',''),'3',''),'4',''),'5',''),'6',''),'7',''),'8',''),'9','')) = 0
      THEN CASE
        WHEN length(cdig) BETWEEN 1 AND 10 THEN substr('0000000000' || cdig, -10, 10)
        ELSE substr(cdig, -10, 10)
      END
    END AS cust,
    CASE
      WHEN dec IS NULL OR dec = '' OR dec = '.' OR (dec ~ '^.*[^0-9.].*$')
           OR length(dec) - length(replace(dec, '.', '')) > 1 THEN NULL
      WHEN strpos(dec, '.') = 0 THEN
        CASE WHEN CAST(dec AS INTEGER) >= 10000 AND CAST(dec AS INTEGER) % 10000 = 0
             THEN CAST(dec AS INTEGER) ELSE CAST(dec AS INTEGER) * 1000000 END
      WHEN replace(substr(dec, strpos(dec, '.') + 1), '0', '') = ''
       AND strpos(dec, '.') > 1
       AND CAST(substr(dec, 1, strpos(dec, '.') - 1) AS INTEGER) >= 10000
       AND CAST(substr(dec, 1, strpos(dec, '.') - 1) AS INTEGER) % 10000 = 0
        THEN CAST(substr(dec, 1, strpos(dec, '.') - 1) AS INTEGER)
      ELSE
        CAST(CASE WHEN strpos(dec, '.') = 1 THEN '0' ELSE substr(dec, 1, strpos(dec, '.') - 1) END AS INTEGER) * 1000000
        + CAST(substr(substr(dec, strpos(dec, '.') + 1) || '000000', 1, 6) AS INTEGER)
        + CASE WHEN length(substr(dec, strpos(dec, '.') + 1)) > 6
                AND substr(substr(dec, strpos(dec, '.') + 1), 7, 1) >= '5' THEN 1 ELSE 0 END
    END * CASE WHEN neg = 1 THEN -1 ELSE 1 END AS micros
  FROM (
    SELECT iid, id_ok, kind, en, epoch, loaded_epoch, adtest, partner, detail, slot_tok, cdig, neg,
      CASE
        WHEN strpos(num, ',') > 0 AND strpos(num, '.') > 0 AND strpos(num, ',') > strpos(num, '.')
          THEN replace(replace(num, '.', ''), ',', '.')
        WHEN strpos(num, ',') > 0 AND strpos(num, '.') > 0 THEN replace(num, ',', '')
        WHEN strpos(num, ',') > 0 AND strpos(substr(num, strpos(num, ',') + 1), ',') = 0
             AND length(substr(num, strpos(num, ',') + 1)) BETWEEN 1 AND 2
          THEN substr(num, 1, strpos(num, ',') - 1) || '.' || substr(num, strpos(num, ',') + 1)
        WHEN strpos(num, ',') > 0 THEN replace(num, ',', '')
        WHEN length(num) - length(replace(num, '.', '')) > 1 THEN replace(num, '.', '')
        ELSE num
      END AS dec
    FROM (
      SELECT iid, id_ok, kind, en, epoch, loaded_epoch, adtest, partner, detail,
             CASE
      WHEN (s2 ~ '^top-[1-4]$') THEN s2
      WHEN (s2 ~ '^top[1-4]$') THEN 'top-' || substr(s2, 4, 1)
      WHEN (s2 ~ '^bottom-[1-3]$') THEN s2
      WHEN (s2 ~ '^bottom[1-3]$') THEN 'bottom-' || substr(s2, 7, 1)
      WHEN (s2 ~ '^mainline-[1-4]$') THEN 'top-' || substr(s2, 10, 1)
      WHEN (s2 ~ '^mainline[1-4]$') THEN 'top-' || substr(s2, 9, 1)
      WHEN (s2 ~ '^above-[1-4]$') THEN 'top-' || substr(s2, 7, 1)
      WHEN (s2 ~ '^above[1-4]$') THEN 'top-' || substr(s2, 6, 1)
      WHEN (s2 ~ '^below-[1-3]$') THEN 'bottom-' || substr(s2, 7, 1)
      WHEN (s2 ~ '^below[1-3]$') THEN 'bottom-' || substr(s2, 6, 1)
      WHEN (s2 ~ '^ml-[1-4]$') THEN 'top-' || substr(s2, 4, 1)
      WHEN (s2 ~ '^ml[1-4]$') THEN 'top-' || substr(s2, 3, 1)
      WHEN (s2 ~ '^btm-[1-3]$') THEN 'bottom-' || substr(s2, 5, 1)
      WHEN (s2 ~ '^btm[1-3]$') THEN 'bottom-' || substr(s2, 4, 1)
      WHEN (s2 ~ '^bot-[1-3]$') THEN 'bottom-' || substr(s2, 5, 1)
      WHEN (s2 ~ '^bot[1-3]$') THEN 'bottom-' || substr(s2, 4, 1)
      WHEN (s2 ~ '^bt-[1-3]$') THEN 'bottom-' || substr(s2, 4, 1)
      WHEN (s2 ~ '^bt[1-3]$') THEN 'bottom-' || substr(s2, 3, 1)
    END AS slot_tok,
             replace(replace(replace(replace(replace(replace(replace(replace(replace(
               coalesce(price_txt, ''), '$',''), chr(8364),''), chr(163),''), chr(165),''), ' ',''), '(',''), ')',''),
               'usd',''), 'eur','') AS num,
             CASE WHEN coalesce(price_txt, '') LIKE '%(%' OR trim(coalesce(price_txt, '')) LIKE '-%' THEN 1 ELSE 0 END AS neg,
             replace(replace(replace(replace(replace(replace(replace(
               CASE
                 WHEN lower(coalesce(cust_raw, '')) IN ('', chr(92)||'n', chr(92)||chr(92)||'n', 'null', 'none', 'nan', 'n/a', 'na', '-', 'undefined', 'nil', '(null)', 'n.a.', 'n.a') OR lower(coalesce(cust_raw, '')) = 'customer_id' THEN ''
                 WHEN (cust_raw ~ '^[0-9].*\.[0].*$')
                  AND strpos(cust_raw, '.') > 0
                  AND strpos(substr(cust_raw, strpos(cust_raw, '.') + 1), '.') = 0
                  AND replace(substr(cust_raw, strpos(cust_raw, '.') + 1), '0', '') = ''
                  AND NOT (substr(cust_raw, 1, strpos(cust_raw, '.') - 1) ~ '^.*[^0-9].*$')
                   THEN substr(cust_raw, 1, strpos(cust_raw, '.') - 1)
                 ELSE coalesce(cust_raw, '')
               END, '-', ''), '.', ''), ' ', ''), '/', ''), '(', ''), ')', ''), '_', '') AS cdig
      FROM (
        SELECT iid, id_ok, kind, en, epoch, loaded_epoch, adtest, partner, detail, cust_raw,
               CASE
      WHEN kind = 'click' AND detail LIKE '{%' AND pg_input_is_valid(detail, 'jsonb') THEN CAST(coalesce(
        (detail::jsonb ->> 'price_micros'), (detail::jsonb ->> 'priceMicros'),
        (detail::jsonb ->> 'cost_micros'), (detail::jsonb ->> 'cpc_micros'),
        (detail::jsonb ->> 'amount_micros'), (detail::jsonb ->> 'micros'),
        (detail::jsonb ->> 'price'), (detail::jsonb ->> 'cpc'),
        (detail::jsonb ->> 'cost'), (detail::jsonb ->> 'amount'),
        (detail::jsonb ->> 'value')) AS TEXT)
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'price_micros=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'price_micros=') + 13, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'price_micros=') + 13), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'price_micros=') + 13), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'cost_micros=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'cost_micros=') + 12, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'cost_micros=') + 12), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'cost_micros=') + 12), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'cpc_micros=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'cpc_micros=') + 11, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'cpc_micros=') + 11), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'cpc_micros=') + 11), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'amount_micros=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'amount_micros=') + 14, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'amount_micros=') + 14), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'amount_micros=') + 14), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'price=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'price=') + 6, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'price=') + 6), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'price=') + 6), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'cpc=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'cpc=') + 4, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'cpc=') + 4), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'cpc=') + 4), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' AND strpos(lower(coalesce(detail, '')), 'cost=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'cost=') + 5, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'cost=') + 5), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'cost=') + 5), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
      WHEN kind = 'click' THEN detail
    END AS price_txt,
               CASE
                 WHEN (s1 ~ '^google-search-.*$') THEN substr(s1, 15)
                 WHEN (s1 ~ '^gsearch-.*$') THEN substr(s1, 9)
                 WHEN (s1 ~ '^search-.*$') THEN substr(s1, 8)
                 WHEN (s1 ~ '^placement-.*$') THEN substr(s1, 11)
                 WHEN (s1 ~ '^position-.*$') THEN substr(s1, 10)
                 WHEN (s1 ~ '^slot-.*$') THEN substr(s1, 6)
                 WHEN (s1 ~ '^pos-.*$') THEN substr(s1, 5)
                 ELSE s1
               END AS s2
        FROM (
          SELECT iid, id_ok, kind, en, epoch, loaded_epoch, adtest, partner, detail, cust_raw,
                 replace(replace(replace(lower(trim(coalesce(slot_src, ''))), '_', '-'), ' ', ''), '"', '') AS s1
          FROM (
            SELECT
              iid, en, epoch, loaded_epoch, cust_raw, detail,
              CASE WHEN length(iid) = 22 AND NOT (iid ~ '^.*[^A-Za-z0-9+/_-].*$') THEN 1 ELSE 0 END AS id_ok,
              CASE
                WHEN en IN ('invalid','invalidated','invalid_click','fraud','fraudulent','bot','sivt','givt','rejected','reject','filtered','spam','fake','blocked','block')
                  OR (en ~ '^invalid.*$') OR (en ~ '^.*fraud.*$') OR (en ~ '^sivt.*$') OR (en ~ '^givt.*$') THEN 'invalid'
                WHEN en IN ('valid','validated','valid_click','legitimate','legit','approved','accepted','accept','allowed','allow','human','clean') OR (en ~ '^valid.*$') THEN 'valid'
                WHEN en IN ('click','clicked','clicks','clk','clks','cpc','ad_click','adclick','click_through','clickthrough','clickthru') OR (en ~ '^click.*$') OR en = 'clk' THEN 'click'
                WHEN en IN ('serve','served','serving','impression','impressions','imp','imps','shown','show','ad_serve','adserve','ad_shown','adshown','display','displayed','render','rendered','delivered','deliver','exposure','exposed','view','viewed','mainline','ml','bottom','bt','btm','bot','above','below','top') OR (en ~ '^impression.*$') OR (en ~ '^serve.*$') THEN 'serve'
                WHEN en IN ('verdict','review','decision','outcome','fraud_check','filter_result','status','judgement','judgment') AND (
                      lower(trim(coalesce(detail, ''))) IN ('invalid','sivt','givt','fraud','fraudulent','bot','rejected','spam','fake','block','blocked')
                   OR (lower(coalesce(detail, '')) ~ '^invalid.*$')
                   OR (lower(coalesce(detail, '')) ~ '^sivt.*$')
                   OR (lower(coalesce(detail, '')) ~ '^givt.*$')) THEN 'invalid'
                WHEN en IN ('verdict','review','decision','outcome','fraud_check','filter_result','status','judgement','judgment') AND (
                      lower(trim(coalesce(detail, ''))) IN ('valid','ok','legitimate','legit','approved','human','clean','accept','accepted','pass','passed')
                   OR (lower(coalesce(detail, '')) ~ '^valid.*$')) THEN 'valid'
              END AS kind,
              CASE
                WHEN en IN ('adtest', 'preview', 'ad_preview', 'adpreview')
                  OR lower(trim(coalesce(detail, ''))) IN ('adtest', 'preview', 'adtest=on', 'adtest=1', 'adtest=true', 'adtest=yes')
                  OR lower(coalesce(detail, '')) LIKE '%adtest=on%'
                  OR lower(coalesce(detail, '')) LIKE '%adtest=1%'
                  OR lower(coalesce(detail, '')) LIKE '%adtest=true%'
                  OR lower(coalesce(detail, '')) LIKE '%adtest=yes%'
                  OR (detail LIKE '{%' AND pg_input_is_valid(detail, 'jsonb')
                      AND lower(CAST((detail::jsonb ->> 'adtest') AS TEXT)) IN ('1', 'true', 'on', 'yes'))
                  THEN 1 ELSE 0
              END AS adtest,
              CASE
                WHEN en IN ('partner', 'partner_serve', 'search_partner')
                  OR lower(replace(trim(coalesce(detail, '')), '_', '-')) IN
                     ('partner', 'search-partner', 'search-partners', 'syndicated', 'afs')
                  OR lower(coalesce(detail, '')) LIKE '%network=search_partner%'
                  OR lower(coalesce(detail, '')) LIKE '%network=search-partner%'
                  OR lower(coalesce(detail, '')) LIKE '%ad_network=search_partner%'
                  OR lower(coalesce(detail, '')) LIKE '%adnetwork=search_partner%'
                  OR (detail LIKE '{%' AND pg_input_is_valid(detail, 'jsonb') AND lower(replace(CAST(
                        coalesce((detail::jsonb ->> 'network'), (detail::jsonb ->> 'ad_network'), '')
                      AS TEXT), '_', '-')) IN ('partner', 'search-partner', 'search-partners', 'syndicated', 'afs'))
                  THEN 1 ELSE 0
              END AS partner,
              CASE
            WHEN detail LIKE '{%' AND pg_input_is_valid(detail, 'jsonb') THEN CAST(coalesce(
              (detail::jsonb ->> 'slot'), (detail::jsonb ->> 'placement'),
              (detail::jsonb ->> 'ad_slot'), (detail::jsonb ->> 'position')) AS TEXT)
            WHEN strpos(lower(detail), 'slot=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'slot=') + 5, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'slot=') + 5), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'slot=') + 5), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
            WHEN strpos(lower(detail), 'placement=') > 0 THEN replace(replace(substr(detail, strpos(lower(detail), 'placement=') + 10, CASE WHEN strpos(substr(detail || '&', strpos(lower(detail), 'placement=') + 10), '&') > 0 THEN strpos(substr(detail || '&', strpos(lower(detail), 'placement=') + 10), '&') - 1 ELSE 48 END), '#', '&'), ' ', '&')
            WHEN strpos(detail, '&') > 0 THEN substr(detail, 1, strpos(detail, '&') - 1)
            WHEN strpos(detail, '|') > 0 THEN substr(detail, 1, strpos(detail, '|') - 1)
            WHEN strpos(detail, ';') > 0 THEN substr(detail, 1, strpos(detail, ';') - 1)
            ELSE detail
          END AS slot_src
            FROM (
              SELECT
                CASE
                  WHEN id1 LIKE '"%"' OR id1 LIKE '''%''' THEN substr(id1, 2, length(id1) - 2)
                  ELSE id1
                END AS iid,
                en, epoch, loaded_epoch, cust_raw, detail
              FROM (
                SELECT CASE WHEN id0 LIKE '%=' THEN rtrim(id0, '=') ELSE id0 END AS id1,
                       en, epoch, loaded_epoch, cust_raw, detail
                FROM (
                  SELECT
                    replace(replace(replace(replace(trim(impression_id), chr(65279), ''), '%2B', '+'), '%2b', '+'), '%2F', '/') AS id0,
                    lower(replace(replace(trim(event), '-', '_'), ' ', '_')) AS en,
                    trim(customer_id) AS cust_raw,
                    detail AS detail,
                    CAST(event_epoch AS INTEGER) AS epoch,
                    CAST(loaded_epoch AS INTEGER) AS loaded_epoch
                  FROM ad_events_history
                  WHERE lower(trim(coalesce(impression_id, ''))) NOT IN ('impression_id', 'id')
                )
              )
            )
            UNION ALL
            SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
          )
        )
        UNION ALL
        SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
      )
      UNION ALL
      SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
    )
    UNION ALL
    SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
  )
)
WHERE id_ok = 1
 
 
-- task: ad_impressions
 
WITH
zv AS (
  SELECT CASE WHEN substr(z.value, 1, 1) = '"' THEN substr(z.value, 2, length(z.value) - 2) ELSE z.value END AS val
  FROM (SELECT '["africa/abidjan|0","africa/accra|0","africa/addis_ababa|10800","africa/algiers|3600","africa/asmara|10800","africa/asmera|10800","africa/bamako|0","africa/bangui|3600","africa/banjul|0","africa/bissau|0","africa/blantyre|7200","africa/brazzaville|3600","africa/bujumbura|7200","africa/cairo|10800|1793307600|7200|1790802000|1793484000|1796076000|1798754400","africa/casablanca|0","africa/ceuta|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","africa/conakry|0","africa/dakar|0","africa/dar_es_salaam|10800","africa/djibouti|10800","africa/douala|3600","africa/el_aaiun|0","africa/freetown|0","africa/gaborone|7200","africa/harare|7200","africa/johannesburg|7200","africa/juba|7200","africa/kampala|10800","africa/khartoum|7200","africa/kigali|7200","africa/kinshasa|3600","africa/lagos|3600","africa/libreville|3600","africa/lome|0","africa/luanda|3600","africa/lubumbashi|7200","africa/lusaka|7200","africa/malabo|3600","africa/maputo|7200","africa/maseru|7200","africa/mbabane|7200","africa/mogadishu|10800","africa/monrovia|0","africa/nairobi|10800","africa/ndjamena|3600","africa/niamey|3600","africa/nouakchott|0","africa/ouagadougou|0","africa/porto-novo|3600","africa/sao_tome|0","africa/timbuktu|0","africa/tripoli|7200","africa/tunis|3600","africa/windhoek|7200","america/adak|-32400|1793530800|-36000|1790845200|1793523600|1796119200|1798797600","america/anchorage|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/anguilla|-14400","america/antigua|-14400","america/araguaina|-10800","america/argentina/buenos_aires|-10800","america/argentina/catamarca|-10800","america/argentina/comodrivadavia|-10800","america/argentina/cordoba|-10800","america/argentina/jujuy|-10800","america/argentina/la_rioja|-10800","america/argentina/mendoza|-10800","america/argentina/rio_gallegos|-10800","america/argentina/salta|-10800","america/argentina/san_juan|-10800","america/argentina/san_luis|-10800","america/argentina/tucuman|-10800","america/argentina/ushuaia|-10800","america/aruba|-14400","america/asuncion|-10800","america/atikokan|-18000","america/atka|-32400|1793530800|-36000|1790845200|1793523600|1796119200|1798797600","america/bahia|-10800","america/bahia_banderas|-21600","america/barbados|-14400","america/belem|-10800","america/belize|-21600","america/blanc-sablon|-14400","america/boa_vista|-14400","america/bogota|-18000","america/boise|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","america/buenos_aires|-10800","america/cambridge_bay|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","america/campo_grande|-14400","america/cancun|-18000","america/caracas|-14400","america/catamarca|-10800","america/cayenne|-10800","america/cayman|-18000","america/chicago|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/chihuahua|-21600","america/ciudad_juarez|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","america/coral_harbour|-18000","america/cordoba|-10800","america/costa_rica|-21600","america/coyhaique|-10800","america/creston|-25200","america/cuiaba|-14400","america/curacao|-14400","america/danmarkshavn|0","america/dawson|-25200","america/dawson_creek|-25200","america/denver|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","america/detroit|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/dominica|-14400","america/edmonton|-21600","america/eirunepe|-18000","america/el_salvador|-21600","america/ensenada|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","america/fort_nelson|-25200","america/fort_wayne|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/fortaleza|-10800","america/glace_bay|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","america/godthab|-3600|1792890000|-7200|1790816400|1793498400|1796090400|1798768800","america/goose_bay|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","america/grand_turk|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/grenada|-14400","america/guadeloupe|-14400","america/guatemala|-21600","america/guayaquil|-18000","america/guyana|-14400","america/halifax|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","america/havana|-14400|1793509200|-18000|1790827200|1793505600|1796101200|1798779600","america/hermosillo|-25200","america/indiana/indianapolis|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indiana/knox|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/indiana/marengo|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indiana/petersburg|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indiana/tell_city|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/indiana/vevay|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indiana/vincennes|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indiana/winamac|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/indianapolis|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/inuvik|-21600","america/iqaluit|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/jamaica|-18000","america/jujuy|-10800","america/juneau|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/kentucky/louisville|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/kentucky/monticello|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/knox_in|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/kralendijk|-14400","america/la_paz|-14400","america/lima|-18000","america/los_angeles|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","america/louisville|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/lower_princes|-14400","america/maceio|-10800","america/managua|-21600","america/manaus|-14400","america/marigot|-14400","america/martinique|-14400","america/matamoros|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/mazatlan|-25200","america/mendoza|-10800","america/menominee|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/merida|-21600","america/metlakatla|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/mexico_city|-21600","america/miquelon|-7200|1793505600|-10800|1790820000|1793498400|1796094000|1798772400","america/moncton|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","america/monterrey|-21600","america/montevideo|-10800","america/montreal|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/montserrat|-14400","america/nassau|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/new_york|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/nipigon|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/nome|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/noronha|-7200","america/north_dakota/beulah|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/north_dakota/center|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/north_dakota/new_salem|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/nuuk|-3600|1792890000|-7200|1790816400|1793498400|1796090400|1798768800","america/ojinaga|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/panama|-18000","america/pangnirtung|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/paramaribo|-10800","america/phoenix|-25200","america/port-au-prince|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/port_of_spain|-14400","america/porto_acre|-18000","america/porto_velho|-14400","america/puerto_rico|-14400","america/punta_arenas|-10800","america/rainy_river|-18000","america/rankin_inlet|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/recife|-10800","america/regina|-21600","america/resolute|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","america/rio_branco|-18000","america/rosario|-10800","america/santa_isabel|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","america/santarem|-10800","america/santiago|-10800","america/santo_domingo|-14400","america/sao_paulo|-10800","america/scoresbysund|-3600|1792890000|-7200|1790816400|1793498400|1796090400|1798768800","america/shiprock|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","america/sitka|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/st_barthelemy|-14400","america/st_johns|-9000|1793507400|-12600|1790821800|1793500200|1796095800|1798774200","america/st_kitts|-14400","america/st_lucia|-14400","america/st_thomas|-14400","america/st_vincent|-14400","america/swift_current|-21600","america/tegucigalpa|-21600","america/thule|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","america/thunder_bay|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/tijuana|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","america/toronto|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","america/tortola|-14400","america/vancouver|-25200","america/virgin|-14400","america/whitehorse|-25200","america/winnipeg|-18000","america/yakutat|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","america/yellowknife|-21600","antarctica/casey|28800","antarctica/davis|25200","antarctica/dumontdurville|36000","antarctica/macquarie|39600","antarctica/mawson|18000","antarctica/mcmurdo|46800","antarctica/palmer|-10800","antarctica/rothera|-10800","antarctica/south_pole|46800","antarctica/syowa|10800","antarctica/troll|7200|1792890000|0|1790805600|1793491200|1796083200|1798761600","antarctica/vostok|18000","arctic/longyearbyen|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","asia/aden|10800","asia/almaty|18000","asia/amman|10800","asia/anadyr|43200","asia/aqtau|18000","asia/aqtobe|18000","asia/ashgabat|18000","asia/ashkhabad|18000","asia/atyrau|18000","asia/baghdad|10800","asia/bahrain|10800","asia/baku|14400","asia/bangkok|25200","asia/barnaul|25200","asia/beirut|10800|1792875600|7200|1790802000|1793484000|1796076000|1798754400","asia/bishkek|21600","asia/brunei|28800","asia/calcutta|19800","asia/chita|32400","asia/choibalsan|28800","asia/chongqing|28800","asia/chungking|28800","asia/colombo|19800","asia/dacca|21600","asia/damascus|10800","asia/dhaka|21600","asia/dili|32400","asia/dubai|14400","asia/dushanbe|18000","asia/famagusta|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","asia/gaza|10800|1792796400|7200|1790802000|1793484000|1796076000|1798754400","asia/harbin|28800","asia/hebron|10800|1792796400|7200|1790802000|1793484000|1796076000|1798754400","asia/ho_chi_minh|25200","asia/hong_kong|28800","asia/hovd|25200","asia/irkutsk|28800","asia/istanbul|10800","asia/jakarta|25200","asia/jayapura|32400","asia/jerusalem|10800|1792882800|7200|1790802000|1793484000|1796076000|1798754400","asia/kabul|16200","asia/kamchatka|43200","asia/karachi|18000","asia/kashgar|21600","asia/kathmandu|20700","asia/katmandu|20700","asia/khandyga|32400","asia/kolkata|19800","asia/krasnoyarsk|25200","asia/kuala_lumpur|28800","asia/kuching|28800","asia/kuwait|10800","asia/macao|28800","asia/macau|28800","asia/magadan|39600","asia/makassar|28800","asia/manila|28800","asia/muscat|14400","asia/nicosia|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","asia/novokuznetsk|25200","asia/novosibirsk|25200","asia/omsk|21600","asia/oral|18000","asia/phnom_penh|25200","asia/pontianak|25200","asia/pyongyang|32400","asia/qatar|10800","asia/qostanay|18000","asia/qyzylorda|18000","asia/rangoon|23400","asia/riyadh|10800","asia/saigon|25200","asia/sakhalin|39600","asia/samarkand|18000","asia/seoul|32400","asia/shanghai|28800","asia/singapore|28800","asia/srednekolymsk|39600","asia/taipei|28800","asia/tashkent|18000","asia/tbilisi|14400","asia/tehran|12600","asia/tel_aviv|10800|1792882800|7200|1790802000|1793484000|1796076000|1798754400","asia/thimbu|21600","asia/thimphu|21600","asia/tokyo|32400","asia/tomsk|25200","asia/ujung_pandang|28800","asia/ulaanbaatar|28800","asia/ulan_bator|28800","asia/urumqi|21600","asia/ust-nera|36000","asia/vientiane|25200","asia/vladivostok|36000","asia/yakutsk|32400","asia/yangon|23400","asia/yekaterinburg|18000","asia/yerevan|14400","atlantic/azores|0|1792890000|-3600|1790812800|1793494800|1796086800|1798765200","atlantic/bermuda|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","atlantic/canary|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","atlantic/cape_verde|-3600","atlantic/faeroe|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","atlantic/faroe|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","atlantic/jan_mayen|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","atlantic/madeira|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","atlantic/reykjavik|0","atlantic/south_georgia|-7200","atlantic/st_helena|0","atlantic/stanley|-10800","australia/act|39600","australia/adelaide|37800","australia/brisbane|36000","australia/broken_hill|37800","australia/canberra|39600","australia/currie|39600","australia/darwin|34200","australia/eucla|31500","australia/hobart|39600","australia/lhi|39600","australia/lindeman|36000","australia/lord_howe|39600","australia/melbourne|39600","australia/north|34200","australia/nsw|39600","australia/perth|28800","australia/queensland|36000","australia/south|37800","australia/sydney|39600","australia/tasmania|39600","australia/victoria|39600","australia/west|28800","australia/yancowinna|37800","brazil/acre|-18000","brazil/denoronha|-7200","brazil/east|-10800","brazil/west|-14400","canada/atlantic|-10800|1793509200|-14400|1790823600|1793502000|1796097600|1798776000","canada/central|-18000","canada/eastern|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","canada/mountain|-21600","canada/newfoundland|-9000|1793507400|-12600|1790821800|1793500200|1796095800|1798774200","canada/pacific|-25200","canada/saskatchewan|-21600","canada/yukon|-25200","cet|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","chile/continental|-10800","chile/easterisland|-18000","cst6cdt|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","cuba|-14400|1793509200|-18000|1790827200|1793505600|1796101200|1798779600","eet|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","egypt|10800|1793307600|7200|1790802000|1793484000|1796076000|1798754400","eire|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","est|-18000","est5edt|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","etc/gmt|0","etc/gmt+0|0","etc/gmt+1|-3600","etc/gmt+10|-36000","etc/gmt+11|-39600","etc/gmt+12|-43200","etc/gmt+2|-7200","etc/gmt+3|-10800","etc/gmt+4|-14400","etc/gmt+5|-18000","etc/gmt+6|-21600","etc/gmt+7|-25200","etc/gmt+8|-28800","etc/gmt+9|-32400","etc/gmt-0|0","etc/gmt-1|3600","etc/gmt-10|36000","etc/gmt-11|39600","etc/gmt-12|43200","etc/gmt-13|46800","etc/gmt-14|50400","etc/gmt-2|7200","etc/gmt-3|10800","etc/gmt-4|14400","etc/gmt-5|18000","etc/gmt-6|21600","etc/gmt-7|25200","etc/gmt-8|28800","etc/gmt-9|32400","etc/gmt0|0","etc/greenwich|0","etc/uct|0","etc/universal|0","etc/utc|0","etc/zulu|0","europe/amsterdam|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/andorra|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/astrakhan|14400","europe/athens|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/belfast|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/belgrade|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/berlin|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/bratislava|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/brussels|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/bucharest|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/budapest|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/busingen|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/chisinau|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/copenhagen|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/dublin|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/gibraltar|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/guernsey|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/helsinki|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/isle_of_man|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/istanbul|10800","europe/jersey|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/kaliningrad|7200","europe/kiev|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/kirov|10800","europe/kyiv|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/lisbon|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/ljubljana|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/london|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","europe/luxembourg|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/madrid|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/malta|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/mariehamn|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/minsk|10800","europe/monaco|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/moscow|10800","europe/nicosia|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/oslo|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/paris|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/podgorica|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/prague|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/riga|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/rome|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/samara|14400","europe/san_marino|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/sarajevo|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/saratov|14400","europe/simferopol|10800","europe/skopje|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/sofia|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/stockholm|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/tallinn|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/tirane|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/tiraspol|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/ulyanovsk|14400","europe/uzhgorod|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/vaduz|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/vatican|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/vienna|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/vilnius|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/volgograd|10800","europe/warsaw|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/zagreb|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","europe/zaporozhye|10800|1792890000|7200|1790802000|1793484000|1796076000|1798754400","europe/zurich|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","factory|0","gb|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","gb-eire|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","gmt|0","gmt+0|0","gmt-0|0","gmt0|0","greenwich|0","hongkong|28800","hst|-36000","iceland|0","indian/antananarivo|10800","indian/chagos|21600","indian/christmas|25200","indian/cocos|23400","indian/comoro|10800","indian/kerguelen|18000","indian/mahe|14400","indian/maldives|18000","indian/mauritius|14400","indian/mayotte|10800","indian/reunion|14400","iran|12600","israel|10800|1792882800|7200|1790802000|1793484000|1796076000|1798754400","jamaica|-18000","japan|32400","kwajalein|43200","libya|7200","met|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","mexico/bajanorte|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","mexico/bajasur|-25200","mexico/general|-21600","mst|-25200","mst7mdt|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","navajo|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","nz|46800","nz-chat|49500","pacific/apia|46800","pacific/auckland|46800","pacific/bougainville|39600","pacific/chatham|49500","pacific/chuuk|36000","pacific/easter|-18000","pacific/efate|39600","pacific/enderbury|46800","pacific/fakaofo|46800","pacific/fiji|43200","pacific/funafuti|43200","pacific/galapagos|-21600","pacific/gambier|-32400","pacific/guadalcanal|39600","pacific/guam|36000","pacific/honolulu|-36000","pacific/johnston|-36000","pacific/kanton|46800","pacific/kiritimati|50400","pacific/kosrae|39600","pacific/kwajalein|43200","pacific/majuro|43200","pacific/marquesas|-34200","pacific/midway|-39600","pacific/nauru|43200","pacific/niue|-39600","pacific/norfolk|43200","pacific/noumea|39600","pacific/pago_pago|-39600","pacific/palau|32400","pacific/pitcairn|-28800","pacific/pohnpei|39600","pacific/ponape|39600","pacific/port_moresby|36000","pacific/rarotonga|-36000","pacific/saipan|36000","pacific/samoa|-39600","pacific/tahiti|-36000","pacific/tarawa|43200","pacific/tongatapu|46800","pacific/truk|36000","pacific/wake|43200","pacific/wallis|43200","pacific/yap|36000","poland|7200|1792890000|3600|1790805600|1793487600|1796079600|1798758000","portugal|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","prc|28800","pst8pdt|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","roc|28800","rok|32400","singapore|28800","turkey|10800","uct|0","universal|0","us/alaska|-28800|1793527200|-32400|1790841600|1793520000|1796115600|1798794000","us/aleutian|-32400|1793530800|-36000|1790845200|1793523600|1796119200|1798797600","us/arizona|-25200","us/central|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","us/east-indiana|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","us/eastern|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","us/hawaii|-36000","us/indiana-starke|-18000|1793516400|-21600|1790830800|1793509200|1796104800|1798783200","us/michigan|-14400|1793512800|-18000|1790827200|1793505600|1796101200|1798779600","us/mountain|-21600|1793520000|-25200|1790834400|1793512800|1796108400|1798786800","us/pacific|-25200|1793523600|-28800|1790838000|1793516400|1796112000|1798790400","us/samoa|-39600","utc|0","w-su|10800","wet|3600|1792890000|0|1790809200|1793491200|1796083200|1798761600","zulu|0"]' AS j) src
  JOIN jsonb_array_elements_text((CASE WHEN pg_input_is_valid(j, 'jsonb') THEN j ELSE '[]' END)::jsonb) z
  UNION ALL SELECT NULL WHERE 0
),
zp0 AS (
  SELECT substr(val, 1, strpos(val, '|') - 1) AS piece,
         substr(val, strpos(val, '|') + 1) AS rest
  FROM zv
  UNION ALL SELECT NULL, NULL WHERE 0
),
zp1 AS (
  SELECT piece, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f1, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp0
  UNION ALL SELECT NULL, NULL, NULL WHERE 0
),
zp2 AS (
  SELECT piece, f1, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f2, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp1
  UNION ALL SELECT NULL, NULL, NULL, NULL WHERE 0
),
zp3 AS (
  SELECT piece, f1, f2, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f3, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp2
  UNION ALL SELECT NULL, NULL, NULL, NULL, NULL WHERE 0
),
zp4 AS (
  SELECT piece, f1, f2, f3, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f4, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp3
  UNION ALL SELECT NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
),
zp5 AS (
  SELECT piece, f1, f2, f3, f4, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f5, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp4
  UNION ALL SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
),
zp6 AS (
  SELECT piece, f1, f2, f3, f4, f5, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f6, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp5
  UNION ALL SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
),
zp7 AS (
  SELECT piece, f1, f2, f3, f4, f5, f6, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN rest ELSE substr(rest, 1, strpos(rest, '|') - 1) END AS f7, CASE WHEN rest = '' OR strpos(rest, '|') = 0 THEN '' ELSE substr(rest, strpos(rest, '|') + 1) END AS rest
  FROM zp6
  UNION ALL SELECT NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL WHERE 0
),
zones AS (
  SELECT piece AS zone,
    CAST(f1 AS INTEGER) AS off1,
    CAST(NULLIF(f2, '') AS INTEGER) AS trans,
    CAST(CASE WHEN f3 = '' THEN f1 ELSE f3 END AS INTEGER) AS off2,
    CAST(CASE WHEN f4 = '' THEN 1790812800 - CAST(f1 AS INTEGER) ELSE f4 END AS INTEGER) AS b_oct,
    CAST(CASE WHEN f5 = '' THEN 1793491200 - CAST(f1 AS INTEGER) ELSE f5 END AS INTEGER) AS b_nov,
    CAST(CASE WHEN f6 = '' THEN 1796083200 - CAST(f1 AS INTEGER) ELSE f6 END AS INTEGER) AS b_dec,
    CAST(CASE WHEN f7 = '' THEN 1798761600 - CAST(f1 AS INTEGER) ELSE f7 END AS INTEGER) AS b_jan
  FROM (SELECT piece, f1, f2, f3, f4, f5, f6, f7 FROM zp7)
),
 
cust_in AS (
  SELECT DISTINCT s FROM (
    SELECT trim(customer_id) AS s FROM accounts_history
  )
  WHERE s IS NOT NULL AND s <> ''
),
cust_prep AS (
  SELECT s,
    replace(replace(replace(replace(replace(replace(replace(
      CASE
        WHEN (s ~ '^[0-9].*\.[0].*$')
         AND strpos(s, '.') > 0
         AND strpos(substr(s, strpos(s, '.') + 1), '.') = 0
         AND replace(substr(s, strpos(s, '.') + 1), '0', '') = ''
         AND NOT (substr(s, 1, strpos(s, '.') - 1) ~ '^.*[^0-9].*$')
          THEN substr(s, 1, strpos(s, '.') - 1)
        ELSE s
      END, '-', ''), '.', ''), ' ', ''), '/', ''), '(', ''), ')', ''), '_', '') AS s2
  FROM cust_in
  WHERE NOT (lower(s) IN ('', chr(92)||'n', chr(92)||chr(92)||'n', 'null', 'none', 'nan', 'n/a', 'na', '-', 'undefined', 'nil', '(null)', 'n.a.', 'n.a') OR lower(s) = 'customer_id')
),
cust_map AS (
  SELECT s,
    CASE
      WHEN length(s2) BETWEEN 1 AND 10 THEN substr('0000000000' || s2, -10, 10)
      WHEN length(s2) BETWEEN 11 AND 13 THEN substr(s2, -10, 10)
    END AS cust
  FROM cust_prep
  WHERE s2 <> '' AND NOT (s2 ~ '^.*[^0-9].*$') AND length(s2) BETWEEN 1 AND 13
),
acc AS (
  SELECT cust, loaded_epoch, zone FROM (
    SELECT m.cust,
           CAST(a.loaded_epoch AS INTEGER) AS loaded_epoch,
           lower(replace(trim(a.time_zone), ' ', '_')) AS zone,
           row_number() OVER (
             PARTITION BY m.cust, a.loaded_epoch
             ORDER BY a._loaded_at DESC
           ) AS rn
    FROM accounts_history a
    JOIN cust_map m ON m.s = trim(a.customer_id)
    WHERE m.cust IS NOT NULL
  )
  WHERE rn = 1 AND loaded_epoch IS NOT NULL AND zone <> ''
),
serve AS (
  SELECT
    iid,
    CAST(substr(max(CASE WHEN kind = 'serve' AND epoch IS NOT NULL
      THEN lpad((coalesce(loaded_epoch, 0))::text, 20, '0') || lpad((epoch)::text, 20, '0') END), 21) AS INTEGER) AS served_epoch,
    nullif(substr(max(CASE WHEN kind = 'serve' AND slot IS NOT NULL
      THEN lpad((coalesce(loaded_epoch, 0))::text, 20, '0') || slot END), 21), '') AS serve_slot,
    nullif(substr(max(CASE WHEN slot IS NOT NULL
      THEN lpad((coalesce(loaded_epoch, 0))::text, 20, '0') || slot END), 21), '') AS any_slot,
    nullif(substr(max(CASE WHEN kind = 'serve' AND cust IS NOT NULL
      THEN lpad((coalesce(loaded_epoch, 0))::text, 20, '0') || cust END), 21), '') AS serve_cust,
    nullif(substr(max(CASE WHEN cust IS NOT NULL
      THEN lpad((coalesce(loaded_epoch, 0))::text, 20, '0') || cust END), 21), '') AS any_cust
  FROM event_norm
  GROUP BY iid
),
serve1 AS (
  SELECT iid, served_epoch,
         coalesce(serve_slot, any_slot) AS slot,
         coalesce(serve_cust, any_cust) AS cust
  FROM serve
  WHERE served_epoch IS NOT NULL
),
asof AS (
  SELECT iid, zone FROM (
    SELECT s.iid, a.zone,
           row_number() OVER (PARTITION BY s.iid ORDER BY a.loaded_epoch DESC) AS rn
    FROM serve1 s
    JOIN acc a ON a.cust = s.cust AND a.loaded_epoch <= s.served_epoch
  )
  WHERE rn = 1
),
first_acc AS (
  SELECT cust, zone FROM (
    SELECT cust, zone, row_number() OVER (PARTITION BY cust ORDER BY loaded_epoch) AS rn
    FROM acc
  )
  WHERE rn = 1
),
flags AS (
  SELECT iid, max(adtest) AS adtest, max(partner) AS partner
  FROM event_norm
  GROUP BY iid
),
serve_z AS (
  SELECT s.iid, s.served_epoch, s.slot, s.cust,
         CASE
           WHEN z.zone IS NULL THEN 0
           WHEN z.trans IS NULL OR s.served_epoch < z.trans THEN z.off1
           ELSE z.off2
         END AS off,
         z.b_oct, z.b_nov, z.b_dec, z.b_jan,
         coalesce(f.adtest, 0) AS adtest,
         coalesce(f.partner, 0) AS partner
  FROM serve1 s
  LEFT JOIN asof o ON o.iid = s.iid
  LEFT JOIN first_acc fa ON fa.cust = s.cust
  LEFT JOIN zones z ON z.zone = coalesce(o.zone, fa.zone)
  LEFT JOIN flags f ON f.iid = s.iid
),
keep AS (
  SELECT *
  FROM serve_z
  WHERE served_epoch >= 1791504000 AND served_epoch < 1794096000
    AND cust IS NOT NULL AND length(cust) = 10
    AND adtest = 0 AND partner = 0
),
clicked AS (
  SELECT DISTINCT e.iid
  FROM event_norm e
  JOIN keep k ON k.iid = e.iid
  WHERE e.kind = 'click'
),
clicks AS (
  SELECT iid, epoch, micros, loaded_epoch,
         row_number() OVER (PARTITION BY iid ORDER BY epoch, coalesce(loaded_epoch, 0), micros) AS rn
  FROM (
    SELECT e.iid,
           coalesce(e.epoch, k.served_epoch) AS epoch,
           e.micros,
           max(e.loaded_epoch) AS loaded_epoch
    FROM event_norm e
    JOIN keep k ON k.iid = e.iid
    WHERE e.kind = 'click' AND e.micros IS NOT NULL
    GROUP BY e.iid, coalesce(e.epoch, k.served_epoch), e.micros
  )
),
c2 AS (
  SELECT c.iid, c.rn, c.micros, c.epoch,
    coalesce(
      CASE to_char(to_timestamp((c.epoch + k.off)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM')
        WHEN '2026-09' THEN k.b_oct
        WHEN '2026-10' THEN k.b_nov
        WHEN '2026-11' THEN k.b_dec
        WHEN '2026-12' THEN k.b_jan
      END,
      2000000000) AS month_end
  FROM clicks c
  JOIN keep k ON k.iid = c.iid
  WHERE c.rn <= 2
),
verd AS (
  SELECT iid, epoch, kind, loaded_epoch FROM (
    SELECT iid, epoch, kind, loaded_epoch,
           row_number() OVER (PARTITION BY iid, epoch ORDER BY loaded_epoch DESC, kind) AS rn
    FROM (
      SELECT e.iid, e.epoch, e.kind, max(e.loaded_epoch) AS loaded_epoch
      FROM event_norm e
      JOIN keep k ON k.iid = e.iid
      WHERE e.kind IN ('valid', 'invalid') AND e.epoch IS NOT NULL
      GROUP BY e.iid, e.epoch, e.kind
    )
  )
  WHERE rn = 1
),
bill_src AS (
  SELECT c.iid, c.rn, c.micros, v.kind,
         row_number() OVER (
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
         CAST(sum(CASE WHEN kind = 'invalid' THEN 0 ELSE micros END) AS INTEGER) AS billed
  FROM bill_src
  WHERE vrn = 1
  GROUP BY iid
)
SELECT
  CAST(k.iid AS TEXT) AS impression_id,
  CAST(k.cust AS TEXT) AS customer_id,
  to_char(to_timestamp((k.served_epoch)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS served_at,
  to_char(to_timestamp((k.served_epoch + k.off)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD') AS served_date,
  k.slot AS slot,
  CASE WHEN c.iid IS NOT NULL THEN 1 ELSE 0 END AS clicked,
  CAST(coalesce(b.billed, 0) AS INTEGER) AS billed_micros
FROM keep k
LEFT JOIN clicked c ON c.iid = k.iid
LEFT JOIN bill b ON b.iid = k.iid
