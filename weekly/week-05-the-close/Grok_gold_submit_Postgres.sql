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

-- ============================================================
-- Grok_gold_submit_Postgres.sql
-- Faithful Postgres port of gold_submit.sql (original dialect: SQLite)
-- Same logic: null-as-text cleaning, timestamp parsing, last-non-null
-- collapse, as-of FX / merchant, minor-unit divisors, settled-in-period.
-- ============================================================

-- task: payments_history
WITH c AS (
  SELECT
    coalesce(payment_id::text, '') || '|' ||
    coalesce(_batch_id::text, '') || '|' ||
    coalesce(_correction_for::text, '') || '|' ||
    coalesce(_loaded_at::text, '') || '|' ||
    coalesce(updated_at::text, '') || '|' ||
    coalesce(status::text, '') || '|' ||
    coalesce(settled::text, '') || '|' ||
    coalesce(captured_at::text, '') || '|' ||
    coalesce(amount::text, '') || '|' ||
    coalesce(currency::text, '') || '|' ||
    coalesce(merchant_id::text, '') AS rk,
    CASE WHEN lower(btrim(payment_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(payment_id::text, E' \t\n\r') END AS payment_id,
    CASE WHEN lower(btrim(merchant_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(merchant_id::text, E' \t\n\r') END AS merchant_id,
    CASE WHEN lower(btrim(amount::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(amount::text, E' \t\n\r') END AS amount,
    CASE WHEN lower(btrim(currency::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(currency::text, E' \t\n\r') END AS currency,
    CASE WHEN lower(btrim(status::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(status::text, E' \t\n\r') END AS status,
    CASE WHEN lower(btrim(settled::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(settled::text, E' \t\n\r') END AS settled,
    CASE WHEN lower(btrim(created_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(created_at::text, E' \t\n\r') END AS created_at,
    CASE WHEN lower(btrim(captured_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(captured_at::text, E' \t\n\r') END AS captured_at,
    CASE WHEN lower(btrim(updated_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(updated_at::text, E' \t\n\r') END AS updated_at,
    CASE WHEN lower(btrim(metadata::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(metadata::text, E' \t\n\r') END AS metadata,
    CASE WHEN lower(btrim(_batch_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(_batch_id::text, E' \t\n\r') END AS bid,
    CASE WHEN lower(btrim(_correction_for::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(_correction_for::text, E' \t\n\r') END AS cfor,
    CASE WHEN lower(btrim(_loaded_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(_loaded_at::text, E' \t\n\r') END AS lat
  FROM raw_payments
),
t AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, metadata, bid, cfor,
    btrim(replace(replace(replace(replace(replace(upper(created_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS cr,
    btrim(replace(replace(replace(replace(replace(upper(captured_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS ca,
    btrim(replace(replace(replace(replace(replace(upper(updated_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS up,
    btrim(replace(replace(replace(replace(replace(upper(lat),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS lo,
    CASE
      WHEN metadata IS NOT NULL AND metadata ~ '^\s*[\{\[]'
      THEN metadata
      ELSE NULL
    END AS mj,
    CASE WHEN strpos(metadata, '"order_ref"') > 0
         THEN ltrim(substr(metadata, strpos(metadata, '"order_ref"') + 11), ' :')
         WHEN strpos(metadata, '"orderRef"') > 0
         THEN ltrim(substr(metadata, strpos(metadata, '"orderRef"') + 11), ' :')
         ELSE NULL
    END AS mrest
  FROM c
),
p AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, bid, cfor,
    CASE WHEN cr IS NULL THEN NULL
      WHEN cr !~ '[^0-9.]' THEN
        CASE WHEN cr::float8 >= 1e11 THEN to_timestamp(cr::float8 / 1000.0)
             WHEN cr::float8 >= 1e8  THEN to_timestamp(cr::float8)
        END
      WHEN length(cr) > 10 AND cr ~ '[+-][0-9]{2}$' THEN (cr || ':00')::timestamptz
      WHEN length(cr) > 10 AND cr ~ '[+-][0-9]{4}$' THEN
        (substr(cr, 1, length(cr) - 2) || ':' || right(cr, 2))::timestamptz
      ELSE cr::timestamptz
    END AS created_ts,
    CASE WHEN ca IS NULL THEN NULL
      WHEN ca !~ '[^0-9.]' THEN
        CASE WHEN ca::float8 >= 1e11 THEN to_timestamp(ca::float8 / 1000.0)
             WHEN ca::float8 >= 1e8  THEN to_timestamp(ca::float8)
        END
      WHEN length(ca) > 10 AND ca ~ '[+-][0-9]{2}$' THEN (ca || ':00')::timestamptz
      WHEN length(ca) > 10 AND ca ~ '[+-][0-9]{4}$' THEN
        (substr(ca, 1, length(ca) - 2) || ':' || right(ca, 2))::timestamptz
      ELSE ca::timestamptz
    END AS captured_ts,
    CASE WHEN up IS NULL THEN NULL
      WHEN up !~ '[^0-9.]' THEN
        CASE WHEN up::float8 >= 1e11 THEN to_timestamp(up::float8 / 1000.0)
             WHEN up::float8 >= 1e8  THEN to_timestamp(up::float8)
        END
      WHEN length(up) > 10 AND up ~ '[+-][0-9]{2}$' THEN (up || ':00')::timestamptz
      WHEN length(up) > 10 AND up ~ '[+-][0-9]{4}$' THEN
        (substr(up, 1, length(up) - 2) || ':' || right(up, 2))::timestamptz
      ELSE up::timestamptz
    END AS updated_ts,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo !~ '[^0-9.]' THEN
        CASE WHEN lo::float8 >= 1e11 THEN to_timestamp(lo::float8 / 1000.0)
             WHEN lo::float8 >= 1e8  THEN to_timestamp(lo::float8)
        END
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{2}$' THEN (lo || ':00')::timestamptz
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{4}$' THEN
        (substr(lo, 1, length(lo) - 2) || ':' || right(lo, 2))::timestamptz
      ELSE lo::timestamptz
    END AS loaded_ts,
    CASE
      WHEN mj IS NOT NULL THEN
        CASE
          WHEN (mj::jsonb) ? 'order_ref' THEN btrim((mj::jsonb)->>'order_ref')
          WHEN (mj::jsonb) ? 'orderRef'  THEN btrim((mj::jsonb)->>'orderRef')
          ELSE NULL
        END
      WHEN mrest IS NOT NULL THEN
        CASE
          WHEN left(mrest, 1) = '"' THEN
            CASE WHEN strpos(substr(mrest, 2), '"') > 0
                 THEN btrim(substr(mrest, 2, strpos(substr(mrest, 2), '"') - 1))
            END
          WHEN strpos(mrest, ',') > 0 THEN btrim(substr(mrest, 1, strpos(mrest, ',') - 1))
          WHEN strpos(mrest, '}') > 0 THEN btrim(substr(mrest, 1, strpos(mrest, '}') - 1))
        END
    END AS order_ref
  FROM t
),
d AS (
  SELECT p.*,
    CASE
      WHEN bid ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(bid, 1, 10)::date
      WHEN bid ~ '^[0-9]{8}$' THEN (substr(bid,1,4) || '-' || substr(bid,5,2) || '-' || substr(bid,7,2))::date
      WHEN bid ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}' THEN replace(substr(bid, 1, 10), '/', '-')::date
    END AS batch_day,
    CASE
      WHEN cfor ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(cfor, 1, 10)::date
      WHEN cfor ~ '^[0-9]{8}$' THEN (substr(cfor,1,4) || '-' || substr(cfor,5,2) || '-' || substr(cfor,7,2))::date
      WHEN cfor ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}' THEN replace(substr(cfor, 1, 10), '/', '-')::date
    END AS corr_day
  FROM p
)
SELECT rk,
  lower(payment_id) AS pid,
  CASE
    WHEN upper(merchant_id) ~ '^M[0-9]{6}$' THEN upper(merchant_id)
    WHEN merchant_id ~ '^[0-9]+$' AND length(merchant_id) BETWEEN 1 AND 6
      THEN 'M' || lpad(merchant_id, 6, '0')
    ELSE upper(merchant_id)
  END AS mid,
  CASE lower(status)
    WHEN 'authorized' THEN 'authorized' WHEN 'authorised' THEN 'authorized'
    WHEN 'captured'   THEN 'captured'   WHEN 'failed'     THEN 'failed'
    WHEN 'voided'     THEN 'voided'     WHEN 'disputed'   THEN 'disputed'
  END AS status_n,
  CASE WHEN amount ~ '[0-9]' AND amount !~ '[^0-9.-]' AND amount !~ '-.*-' AND amount !~ '\..*\.'
       THEN amount END AS amt,
  CASE WHEN settled ~ '[0-9]' AND settled !~ '[^0-9.-]' AND settled !~ '-.*-' AND settled !~ '\..*\.'
       THEN settled END AS stl,
  CASE WHEN upper(currency) ~ '^[A-Z]{3}$' THEN upper(currency) END AS cur,
  CASE WHEN created_ts BETWEEN '1990-01-01'::timestamptz AND '2100-01-01'::timestamptz
       THEN created_ts END AS created_ts,
  CASE WHEN captured_ts BETWEEN '1990-01-01'::timestamptz AND '2100-01-01'::timestamptz
       THEN captured_ts END AS captured_ts,
  CASE WHEN updated_ts BETWEEN '1990-01-01'::timestamptz AND '2100-01-01'::timestamptz
       THEN updated_ts END AS updated_ts,
  CASE WHEN loaded_ts BETWEEN '1990-01-01'::timestamptz AND '2100-01-01'::timestamptz
       THEN loaded_ts END AS loaded_ts,
  CASE WHEN order_ref <> '' AND lower(order_ref) NOT IN ('null','none') THEN order_ref END AS order_ref,
  batch_day,
  coalesce(corr_day, batch_day,
           (CASE WHEN loaded_ts BETWEEN '1990-01-01'::timestamptz AND '2100-01-01'::timestamptz
                 THEN (loaded_ts - interval '1 day')::date END)
  ) AS eff_day
FROM d;

-- task: fx_history
WITH c AS (
  SELECT
    coalesce(rate_date::text, '') || '|' ||
    coalesce(currency::text, '') || '|' ||
    coalesce(usd_rate::text, '') || '|' ||
    coalesce(_batch_id::text, '') || '|' ||
    coalesce(_loaded_at::text, '') AS rk,
    CASE WHEN lower(btrim(rate_date::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(rate_date::text, E' \t\n\r') END AS rd,
    CASE WHEN lower(btrim(currency::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(currency::text, E' \t\n\r') END AS currency,
    CASE WHEN lower(btrim(usd_rate::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE replace(btrim(usd_rate::text, E' \t\n\r'), ',', '.') END AS rate,
    CASE WHEN lower(btrim(_batch_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(_batch_id::text, E' \t\n\r') END AS bid,
    CASE WHEN lower(btrim(_loaded_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL
      ELSE btrim(replace(replace(replace(replace(replace(upper(btrim(_loaded_at::text, E' \t\n\r')),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' '))
    END AS lo
  FROM raw_fx_rates
),
p AS (
  SELECT rk,
    CASE WHEN upper(currency) ~ '^[A-Z]{3}$' THEN upper(currency) END AS cur,
    coalesce(
      CASE
        WHEN rd ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(rd, 1, 10)::date
        WHEN rd ~ '^[0-9]{8}$' THEN (substr(rd,1,4)||'-'||substr(rd,5,2)||'-'||substr(rd,7,2))::date
        WHEN rd ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}' THEN replace(substr(rd,1,10),'/','-')::date
      END,
      CASE
        WHEN bid ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(bid, 1, 10)::date
        WHEN bid ~ '^[0-9]{8}$' THEN (substr(bid,1,4)||'-'||substr(bid,5,2)||'-'||substr(bid,7,2))::date
      END
    ) AS rate_day,
    CASE WHEN rate ~ '[0-9]' AND rate !~ '[^0-9.]' AND rate !~ '\..*\.' AND rate::float8 > 0
         THEN rate::float8 END AS rate,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo !~ '[^0-9.]' THEN
        CASE WHEN lo::float8 >= 1e11 THEN to_timestamp(lo::float8 / 1000.0)
             WHEN lo::float8 >= 1e8  THEN to_timestamp(lo::float8)
        END
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{2}$' THEN (lo || ':00')::timestamptz
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{4}$' THEN
        (substr(lo, 1, length(lo) - 2) || ':' || right(lo, 2))::timestamptz
      ELSE lo::timestamptz
    END AS loaded_ts
  FROM c
)
SELECT rk, cur, rate_day, rate, loaded_ts FROM p;

-- task: merchants_history
WITH c AS (
  SELECT
    coalesce(merchant_id::text, '') || '|' ||
    coalesce(name::text, '') || '|' ||
    coalesce(country::text, '') || '|' ||
    coalesce(is_test::text, '') || '|' ||
    coalesce(_batch_id::text, '') || '|' ||
    coalesce(_loaded_at::text, '') AS rk,
    CASE WHEN lower(btrim(merchant_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(merchant_id::text, E' \t\n\r') END AS merchant_id,
    upper(btrim(country::text, E' \t\n\r')) AS country,
    lower(btrim(is_test::text, E' \t\n\r')) AS is_test,
    CASE WHEN lower(btrim(_batch_id::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL ELSE btrim(_batch_id::text, E' \t\n\r') END AS bid,
    CASE WHEN lower(btrim(_loaded_at::text, E' \t\n\r')) IN
      ('','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?')
      THEN NULL
      ELSE btrim(replace(replace(replace(replace(replace(upper(btrim(_loaded_at::text, E' \t\n\r')),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' '))
    END AS lo
  FROM raw_merchants
),
p AS (
  SELECT rk,
    CASE
      WHEN upper(merchant_id) ~ '^M[0-9]{6}$' THEN upper(merchant_id)
      WHEN merchant_id ~ '^[0-9]+$' AND length(merchant_id) BETWEEN 1 AND 6
        THEN 'M' || lpad(merchant_id, 6, '0')
      ELSE upper(merchant_id)
    END AS mid,
    CASE WHEN country ~ '^[A-Z]{2}$' THEN country END AS country,
    CASE WHEN is_test IN ('t','true','1','y','yes') THEN 1
         WHEN is_test IN ('f','false','0','n','no') THEN 0 END AS is_test,
    CASE
      WHEN bid ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN substr(bid, 1, 10)::date
      WHEN bid ~ '^[0-9]{8}$' THEN (substr(bid,1,4)||'-'||substr(bid,5,2)||'-'||substr(bid,7,2))::date
    END AS bday,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo !~ '[^0-9.]' THEN
        CASE WHEN lo::float8 >= 1e11 THEN to_timestamp(lo::float8 / 1000.0)
             WHEN lo::float8 >= 1e8  THEN to_timestamp(lo::float8)
        END
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{2}$' THEN (lo || ':00')::timestamptz
      WHEN length(lo) > 10 AND lo ~ '[+-][0-9]{4}$' THEN
        (substr(lo, 1, length(lo) - 2) || ':' || right(lo, 2))::timestamptz
      ELSE lo::timestamptz
    END AS loaded_ts
  FROM c
)
SELECT rk, mid, country, is_test,
       coalesce(bday, (loaded_ts - interval '1 day')::date) AS batch_day,
       loaded_ts
FROM p;

-- task: fct_payments
WITH p AS (
  SELECT *,
    coalesce(eff_day::text, '0000-00-00')
      || coalesce(loaded_ts::text, '0000-00-00 00:00:00')
      || coalesce(updated_ts::text, '0000-00-00 00:00:00') AS k
  FROM payments_history
  WHERE pid ~ '^pay_.{8}$'
),
g AS (
  SELECT pid,
    nullif(substr(max(k || coalesce(status_n, '')), 49), '') AS status,
    substr(max(CASE WHEN amt IS NOT NULL THEN k || amt END), 49) AS amt,
    substr(max(CASE WHEN cur IS NOT NULL THEN k || cur END), 49) AS cur,
    substr(max(CASE WHEN created_ts IS NOT NULL THEN k || created_ts::text END), 49) AS created_ts,
    substr(max(CASE WHEN mid IS NOT NULL THEN k || mid END), 49) AS mid,
    substr(max(CASE WHEN order_ref IS NOT NULL THEN k || order_ref END), 49) AS order_ref,
    nullif(substr(max(k || coalesce(captured_ts::text, '')), 49), '') AS cap_last,
    substr(max(CASE WHEN captured_ts IS NOT NULL THEN k || captured_ts::text END), 49) AS cap_any
  FROM p
  GROUP BY pid
),
sd AS (
  SELECT pid, eff_day,
    substr(max(coalesce(loaded_ts::text, '0000-00-00 00:00:00')
              || coalesce(updated_ts::text, '0000-00-00 00:00:00')
              || stl), 39) AS stl
  FROM p
  WHERE stl IS NOT NULL
  GROUP BY pid, eff_day
),
gd AS (
  SELECT g.*,
    CASE WHEN cur IN ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') THEN 1.0
         WHEN cur IN ('BHD','IQD','JOD','KWD','LYD','OMR','TND') THEN 1000.0
         ELSE 100.0 END AS dv,
    created_ts::date AS cday
  FROM g
),
st AS (
  SELECT sd.pid,
    sum(CASE WHEN strpos(sd.stl, '.') > 0 THEN round(sd.stl::float8 * gd.dv)
             ELSE sd.stl::float8 END) AS st_all,
    sum(CASE WHEN sd.eff_day BETWEEN '2026-02-02' AND '2026-02-26' THEN
          CASE WHEN strpos(sd.stl, '.') > 0 THEN round(sd.stl::float8 * gd.dv)
               ELSE sd.stl::float8 END
         ELSE 0 END) AS st_in
  FROM sd
  JOIN gd ON gd.pid = sd.pid
  GROUP BY sd.pid
),
fx1 AS (
  SELECT cur, rate_day, rate FROM (
    SELECT cur, rate_day, rate,
      row_number() OVER (PARTITION BY cur, rate_day ORDER BY loaded_ts DESC NULLS LAST, rk DESC) AS rn
    FROM fx_history
    WHERE cur IS NOT NULL AND rate_day IS NOT NULL AND rate > 0
  ) s WHERE rn = 1
),
fxm AS (
  SELECT cur, rate AS med FROM (
    SELECT cur, rate,
      row_number() OVER (PARTITION BY cur ORDER BY rate) AS rn,
      count(*) OVER (PARTITION BY cur) AS n
    FROM fx1
  ) s WHERE rn = (n + 1) / 2
),
fx2 AS (
  SELECT f.cur, f.rate_day,
    CASE WHEN f.rate / m.med BETWEEN 0.9 AND 1.11 THEN f.rate
         WHEN (1.0 / f.rate) / m.med BETWEEN 0.9 AND 1.11 THEN 1.0 / f.rate
    END AS rate
  FROM fx1 f
  JOIN fxm m ON m.cur = f.cur
),
fx3 AS (
  SELECT cur, rate_day, rate,
    lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day
  FROM fx2
  WHERE rate IS NOT NULL
),
m1 AS (
  SELECT mid, batch_day, country, is_test FROM (
    SELECT mid, batch_day, country, is_test,
      row_number() OVER (PARTITION BY mid, batch_day ORDER BY loaded_ts DESC NULLS LAST, rk DESC) AS rn
    FROM merchants_history
    WHERE mid IS NOT NULL AND batch_day IS NOT NULL
  ) s WHERE rn = 1
),
mc AS (
  SELECT mid, batch_day, country,
    lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1
  WHERE country IS NOT NULL
),
mt AS (
  SELECT mid, batch_day, is_test,
    lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1
  WHERE is_test IS NOT NULL
),
mf AS (
  SELECT mid,
    count(DISTINCT country) AS n_country,
    substr(min(CASE WHEN country IS NOT NULL THEN batch_day::text || country END), 11) AS first_country,
    (substr(min(CASE WHEN is_test IS NOT NULL THEN batch_day::text || is_test::text END), 11))::int AS first_test
  FROM m1
  GROUP BY mid
),
j AS (
  SELECT gd.*,
    coalesce(fx3.rate, CASE WHEN gd.cur = 'USD' THEN 1.0 END) AS rate,
    coalesce(mc.country, CASE WHEN mf.n_country = 1 THEN mf.first_country END) AS country,
    coalesce(mt.is_test, mf.first_test, 0) AS is_test,
    coalesce(st.st_all, 0) AS st_all,
    coalesce(st.st_in, 0) AS st_in
  FROM gd
  LEFT JOIN fx3 ON fx3.cur = gd.cur
               AND gd.cday >= fx3.rate_day
               AND (fx3.next_day IS NULL OR gd.cday < fx3.next_day)
  LEFT JOIN mc  ON mc.mid = gd.mid
               AND gd.cday >= mc.batch_day
               AND (mc.next_day IS NULL OR gd.cday < mc.next_day)
  LEFT JOIN mt  ON mt.mid = gd.mid
               AND gd.cday >= mt.batch_day
               AND (mt.next_day IS NULL OR gd.cday < mt.next_day)
  LEFT JOIN mf  ON mf.mid = gd.mid
  LEFT JOIN st  ON st.pid = gd.pid
),
v AS (
  SELECT j.*,
    CASE WHEN amt IS NULL THEN NULL
         WHEN strpos(amt, '.') > 0 THEN amt::float8
         ELSE amt::float8 / dv
    END * rate AS amount_raw,
    st_all / dv * rate AS settled_raw,
    st_in  / dv * rate AS in_raw
  FROM j
)
SELECT pid AS payment_id,
  status,
  round((amount_raw + CASE WHEN amount_raw < 0 THEN -1e-9 ELSE 1e-9 END)::numeric, 2) AS amount_usd,
  round((settled_raw + CASE WHEN settled_raw < 0 THEN -1e-9 ELSE 1e-9 END)::numeric, 2) AS settled_usd,
  round((in_raw + CASE WHEN in_raw < 0 THEN -1e-9 ELSE 1e-9 END)::numeric, 2) AS settled_in_period_usd,
  replace(
    CASE WHEN cap_last IS NOT NULL THEN cap_last
         WHEN status IN ('captured', 'disputed') THEN cap_any
    END, ' ', 'T'
  ) || 'Z' AS captured_at,
  order_ref,
  country AS merchant_country
FROM v
WHERE is_test = 0;
