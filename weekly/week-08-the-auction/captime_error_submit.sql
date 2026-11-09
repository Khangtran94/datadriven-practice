/* dag.yml
dag: the_auction
schedule: nightly           # 08:00 UTC
start_date: 2026-10-09
end_date: 2026-11-07
tasks:                      # depends_on = the edges; materialized: table | incremental | snapshot | view | test | sensor
  
  event_version:
    materialized: incremental
    depends_on: [ad_events]
    incremental_strategy: merge
    unique_key:
    - event_key
  ad_events_history:
    materialized: incremental
    depends_on: [event_version]
    incremental_strategy: merge
    unique_key:
    - event_key
    
  account_version:
    materialized: incremental
    depends_on: [accounts]
    incremental_strategy: merge
    unique_key:
    - account_key
  accounts_history:
    materialized: incremental
    depends_on: [account_version]
    incremental_strategy: merge
    unique_key:
    - account_key
    
  ad_impressions:
    materialized: table
    depends_on: [ad_events_history, accounts_history]
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after

-- task: ad_events_history
with merge_incremental AS (
    SELECT d.*
    FROM event_version AS d
    {% if is_incremental() %}
    LEFT JOIN {{ this }} AS x
      ON x.event_key = d.event_key
    WHERE x.event_key IS NULL
    {% endif %})

SELECT *
FROM merge_incremental;

-- task: accounts_history
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

-- task: account_version
-- replace null values
WITH replace_null AS (
    SELECT
        CASE WHEN lower(trim(customer_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(customer_id, ' '||char(9,10,13)) END AS customer_id,

        CASE WHEN lower(trim(time_zone, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(time_zone, ' '||char(9,10,13)) END AS time_zone,

        CASE WHEN lower(trim(currency_code, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(currency_code, ' '||char(9,10,13)) END AS currency_code,

        CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS load_at

    FROM accounts),

-- normalize customer_id, timezone
normalized AS
(SELECT REPLACE(REPLACE(REPLACE(REPLACE(customer_id, '-', ''), '_', ''), '/', ''), ' ', '') AS customer_id,
        time_zone,
        CASE WHEN LENGTH(currency_code) <= 3 THEN UPPER(TRIM(currency_code)) ELSE NULL
        END AS currency_code,
        load_at,
        SUBSTR(load_at, 1, 10) AS load_date
FROM replace_null),

-- finalize customer_id, create date_at
finalized AS
(SELECT
    CASE WHEN REGEXP_LIKE(TRIM(customer_id), '^[0-9]+$')
        THEN LPAD(TRIM(customer_id), 10, '0') ELSE NULL
    END AS customer_id,
    time_zone, currency_code, load_at, load_date
FROM normalized),

-- create key account version
key_account_day AS (
SELECT
    COALESCE(f.customer_id, '') || '|' || COALESCE(f.time_zone, '') || '|' || COALESCE(f.currency_code, '') || '|' || COALESCE(f.load_date, '') AS account_key,
    f.*
FROM finalized AS f
WHERE customer_id IS NOT NULL),
    
-- version rownum
rownum_day AS
(SELECT k.*,
        ROW_NUMBER() OVER(PARTITION BY account_key ORDER BY load_at DESC) AS rn
FROM key_account_day AS k),

-- dedup version
dedup AS
(SELECT r.account_key, r.customer_id, r.time_zone, r.currency_code, r.load_at, r.load_date
FROM rownum_day AS r
WHERE rn = 1)

SELECT *
FROM dedup;

-- task: event_version
-- replace null values
WITH replace_null AS 
(SELECT
        CASE WHEN lower(trim(impression_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(impression_id, ' '||char(9,10,13)) END AS impression_id,

        CASE WHEN lower(trim(event, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(event, ' '||char(9,10,13)) END AS event,

        CASE WHEN lower(trim(event_time, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(event_time, ' '||char(9,10,13)) END AS event_time,

        CASE WHEN lower(trim(customer_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(customer_id, ' '||char(9,10,13)) END AS customer_id,

        CASE WHEN lower(trim(detail, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(detail, ' '||char(9,10,13)) END AS detail,

        CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
        THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS loaded_at

FROM ad_events),

-- normalize customer_id, timezone
normalized AS
(SELECT 
    CASE WHEN length(impression_id) = 22 AND regexp_like(impression_id, '^[A-Za-z0-9+/]{22}$') THEN impression_id ELSE NULL END AS impression_id,
-- column event
    CASE
    WHEN lower(trim(event)) IN ('serve','served','serving','ad_serve','ad_served','ad_serving','ad_delivery','ad_delivered','impression','impressions','ad_impression','ad_impressions','display','displayed','render','rendered','ad_render','ad_rendered','auction_win','auction_won','won','bid_won') THEN 'serve'
    WHEN lower(trim(event)) IN ('click','clicked','clicking','ad_click','ad_clicked','ad_clicks','link_click','link_clicked','tap','tapped','ad_tap','interaction','interacted') THEN 'click'
    WHEN lower(trim(event)) IN ('invalid','fraud','fraudulent','fraud_detected','ad_fraud','click_fraud','invalid_click','invalid_clicks','invalid_traffic','ivt','sivt','givt','bot','bot_traffic','bot_detected','automated_traffic','suspicious','suspicious_activity','non_human_traffic','spam','fake_click','fake_impression') THEN 'invalid'
    WHEN lower(trim(event)) IN ('valid','verified','legitimate','accepted','approved','qualified','genuine') THEN 'valid'
    ELSE NULL END AS event_category,
-- column event_time
    CASE
    -- Microseconds (16 digits)
    WHEN regexp_like(event_time, '^[0-9]{16}$')
    THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE) / 1000000.0, 'unixepoch')
    -- Milliseconds (13 digits)
    WHEN regexp_like(event_time, '^[0-9]{13}$')
    THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE) / 1000.0, 'unixepoch')
    -- Seconds (10 digits)
    WHEN regexp_like(event_time, '^[0-9]{10}$')
    THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(event_time AS DOUBLE), 'unixepoch')
    END AS event_time,
-- column customer
    REPLACE(REPLACE(REPLACE(REPLACE(customer_id, '-', ''), '_', ''), '/', ''), ' ', '') AS customer_id,
-- column detail
    CASE
    WHEN lower(detail) IN ('top-1', 'top1', 'top_1', 'top 1', 'top-01', 'top01', 'top_01', 'top 01') THEN 'top-1'
    WHEN lower(detail) IN ('top-2', 'top2', 'top_2', 'top 2', 'top-02', 'top02', 'top_02', 'top 02') THEN 'top-2'
    WHEN lower(detail) IN ('top-3', 'top3', 'top_3', 'top 3', 'top-03', 'top03', 'top_03', 'top 03') THEN 'top-3'
    WHEN lower(detail) IN ('top-4', 'top4', 'top_4', 'top 4', 'top-04', 'top04', 'top_04', 'top 04') THEN 'top-4'
    WHEN lower(detail) IN ('bottom-1', 'bottom1', 'bottom_1', 'bottom 1', 'bottom-01', 'bottom01', 'bottom_01', 'bottom 01') THEN 'bottom-1'
    WHEN lower(detail) IN ('bottom-2', 'bottom2', 'bottom_2', 'bottom 2', 'bottom-02', 'bottom02', 'bottom_02', 'bottom 02') THEN 'bottom-2'
    WHEN lower(detail) IN ('bottom-3', 'bottom3', 'bottom_3', 'bottom 3', 'bottom-03', 'bottom03', 'bottom_03', 'bottom 03') THEN 'bottom-3'
    WHEN detail <> '' AND regexp_like(detail, '^[+-]?[0-9]+(\.[0-9]+)?$') THEN CAST(CAST(detail AS INTEGER) AS VARCHAR)
    ELSE NULL END AS raw_detail,
    loaded_at
FROM replace_null),

finalized AS
(SELECT
    impression_id,
    event_category,
    event_time,
    CASE WHEN REGEXP_LIKE(TRIM(customer_id), '^[0-9]+$')
    THEN LPAD(TRIM(customer_id), 10, '0') ELSE NULL END AS customer_id,
    raw_detail, 
    loaded_at
FROM normalized),

-- create key event version
key_event_day AS (
SELECT
    COALESCE(f.impression_id, '') || '|' || COALESCE(f.event_category, '') || '|' || COALESCE(f.event_time, '') || '|' || COALESCE(f.customer_id, '') || '|' || COALESCE(f.raw_detail, '') AS event_key,
    f.*
FROM finalized AS f),
    
-- version rownum
rownum_day AS
(SELECT k.*,
        ROW_NUMBER() OVER(PARTITION BY event_key ORDER BY loaded_at DESC) AS rn
FROM key_event_day AS k),

-- dedup version
dedup AS
(SELECT r.event_key, r.impression_id, r.event_category, r.event_time, r.customer_id, r.raw_detail, r.loaded_at
FROM rownum_day AS r
WHERE rn = 1)

SELECT *
FROM dedup;

-- task: ad_impressions
WITH ev AS (
    SELECT impression_id, event_key, event_category,
           event_time, customer_id, raw_detail
    FROM ad_events_history
    WHERE impression_id IS NOT NULL
),

-- serve: giữ 1 dòng sớm nhất cho mỗi impression
serve_ranked AS (
    SELECT impression_id,
           customer_id,
           event_time AS served_at,
           raw_detail AS detail,
           ROW_NUMBER() OVER (
               PARTITION BY impression_id
               ORDER BY event_time, event_key) AS rn
    FROM ev
    WHERE event_category = 'serve'
),

serve AS (
    SELECT impression_id, customer_id, served_at, detail,
           served_at::timestamptz AS served_ts
    FROM serve_ranked
    WHERE rn = 1
),

-- ép kiểu load_at một lần
acct AS (
    SELECT customer_id, time_zone,
           load_at::timestamptz AS load_ts
    FROM accounts_history
),

account_choices AS (
    SELECT s.impression_id,
           s.customer_id,
           s.served_at,
           s.detail,
           a.time_zone,
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

serve_account AS (
    SELECT impression_id,
           customer_id,
           served_at,
           detail,
           DATE(TZ_CONVERT(served_at, 'UTC', COALESCE(time_zone, 'UTC')))::date AS served_date
    FROM account_choices
    WHERE account_rank = 1
),

-- click: chỉ window trên các dòng click
click_ranked AS (
    SELECT impression_id,
           raw_detail,
           ROW_NUMBER() OVER (
               PARTITION BY impression_id
               ORDER BY event_time, event_key) AS rn
    FROM ev
    WHERE event_category = 'click'
),

click_agg AS (
    SELECT impression_id,
           SUM(CASE WHEN regexp_like(raw_detail, '^-?[0-9]+$')
                    THEN CAST(raw_detail AS BIGINT) ELSE 0 END) AS billed_micros
    FROM click_ranked
    WHERE rn <= 2
    GROUP BY impression_id
),

-- impression có sự kiện cuối cùng là 'invalid' (không cần sort)
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

SELECT sa.impression_id,
       sa.customer_id,
       sa.served_at,
       sa.served_date,
       sa.detail AS slot,
       CASE WHEN c.impression_id IS NOT NULL THEN 1 ELSE 0 END AS clicked,
       CASE WHEN f.impression_id IS NOT NULL THEN 0
            ELSE COALESCE(c.billed_micros, 0) END AS billed_micros
FROM serve_account AS sa
LEFT JOIN click_agg    AS c ON c.impression_id = sa.impression_id
LEFT JOIN invalid_flag AS f ON f.impression_id = sa.impression_id;
