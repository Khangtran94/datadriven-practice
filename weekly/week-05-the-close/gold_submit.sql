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
  SELECT
    quote(payment_id)||'|'||quote(_batch_id)||'|'||quote(_correction_for)||'|'||quote(_loaded_at)||'|'||quote(updated_at)||'|'||quote(status)||'|'||quote(settled)||'|'||quote(captured_at)||'|'||quote(amount)||'|'||quote(currency)||'|'||quote(merchant_id) AS rk,
    CASE WHEN lower(trim(payment_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(payment_id, ' '||char(9,10,13)) END AS payment_id,
    CASE WHEN lower(trim(merchant_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(merchant_id, ' '||char(9,10,13)) END AS merchant_id,
    CASE WHEN lower(trim(amount, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(amount, ' '||char(9,10,13)) END AS amount,
    CASE WHEN lower(trim(currency, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(currency, ' '||char(9,10,13)) END AS currency,
    CASE WHEN lower(trim(status, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(status, ' '||char(9,10,13)) END AS status,
    CASE WHEN lower(trim(settled, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(settled, ' '||char(9,10,13)) END AS settled,
    CASE WHEN lower(trim(created_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(created_at, ' '||char(9,10,13)) END AS created_at,
    CASE WHEN lower(trim(captured_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(captured_at, ' '||char(9,10,13)) END AS captured_at,
    CASE WHEN lower(trim(updated_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(updated_at, ' '||char(9,10,13)) END AS updated_at,
    CASE WHEN lower(trim(metadata, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(metadata, ' '||char(9,10,13)) END AS metadata,
    CASE WHEN lower(trim(_batch_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid,
    CASE WHEN lower(trim(_correction_for, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(_correction_for, ' '||char(9,10,13)) END AS cfor,
    CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(_loaded_at, ' '||char(9,10,13)) END AS lat
  FROM raw_payments
),
t AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, metadata, bid, cfor,
    trim(replace(replace(replace(replace(replace(upper(created_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS cr,
    trim(replace(replace(replace(replace(replace(upper(captured_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS ca,
    trim(replace(replace(replace(replace(replace(upper(updated_at),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS up,
    trim(replace(replace(replace(replace(replace(upper(lat),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) AS lo,
    CASE WHEN json_valid(metadata) THEN
      CASE WHEN json_type(metadata) = 'text' AND json_valid(json_extract(metadata, '$')) THEN json_extract(metadata, '$') ELSE metadata END
    END AS mj,
    CASE WHEN instr(metadata, '"order_ref"') > 0 THEN ltrim(substr(metadata, instr(metadata, '"order_ref"') + 11), ' :') END AS mrest
  FROM c
),
p AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, bid, cfor,
    CASE WHEN cr IS NULL THEN NULL
      WHEN cr NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(cr AS REAL) >= 1e11 THEN datetime(CAST(cr AS REAL) / 1000.0, 'unixepoch') WHEN CAST(cr AS REAL) >= 1e8 THEN datetime(CAST(cr AS REAL), 'unixepoch') END
      WHEN length(cr) > 10 AND cr GLOB '*[+-][0-9][0-9]' THEN datetime(cr || ':00')
      WHEN length(cr) > 10 AND cr GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(cr, 1, length(cr) - 2) || ':' || substr(cr, -2))
      ELSE datetime(cr) END AS created_ts,
    CASE WHEN ca IS NULL THEN NULL
      WHEN ca NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(ca AS REAL) >= 1e11 THEN datetime(CAST(ca AS REAL) / 1000.0, 'unixepoch') WHEN CAST(ca AS REAL) >= 1e8 THEN datetime(CAST(ca AS REAL), 'unixepoch') END
      WHEN length(ca) > 10 AND ca GLOB '*[+-][0-9][0-9]' THEN datetime(ca || ':00')
      WHEN length(ca) > 10 AND ca GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(ca, 1, length(ca) - 2) || ':' || substr(ca, -2))
      ELSE datetime(ca) END AS captured_ts,
    CASE WHEN up IS NULL THEN NULL
      WHEN up NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(up AS REAL) >= 1e11 THEN datetime(CAST(up AS REAL) / 1000.0, 'unixepoch') WHEN CAST(up AS REAL) >= 1e8 THEN datetime(CAST(up AS REAL), 'unixepoch') END
      WHEN length(up) > 10 AND up GLOB '*[+-][0-9][0-9]' THEN datetime(up || ':00')
      WHEN length(up) > 10 AND up GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(up, 1, length(up) - 2) || ':' || substr(up, -2))
      ELSE datetime(up) END AS updated_ts,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL) / 1000.0, 'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL), 'unixepoch') END
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9]' THEN datetime(lo || ':00')
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(lo, 1, length(lo) - 2) || ':' || substr(lo, -2))
      ELSE datetime(lo) END AS loaded_ts,
    CASE
      WHEN mj IS NOT NULL THEN
        CASE WHEN json_type(mj) = 'object' AND json_type(mj, '$.order_ref') IN ('text', 'integer', 'real')
             THEN trim(CAST(json_extract(mj, '$.order_ref') AS TEXT)) END
      WHEN mrest IS NOT NULL THEN
        CASE WHEN substr(mrest, 1, 1) = '"' THEN
               CASE WHEN instr(substr(mrest, 2), '"') > 0 THEN trim(substr(mrest, 2, instr(substr(mrest, 2), '"') - 1)) END
             WHEN instr(mrest, ',') > 0 THEN trim(substr(mrest, 1, instr(mrest, ',') - 1))
             WHEN instr(mrest, '}') > 0 THEN trim(substr(mrest, 1, instr(mrest, '}') - 1)) END
    END AS order_ref
  FROM t
),
d AS (
  SELECT p.*,
    CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid, 1, 10))
         WHEN bid GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN date(substr(bid, 1, 4) || '-' || substr(bid, 5, 2) || '-' || substr(bid, 7, 2))
         WHEN bid GLOB '[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9]*' THEN date(replace(substr(bid, 1, 10), '/', '-')) END AS batch_day,
    CASE WHEN cfor GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(cfor, 1, 10))
         WHEN cfor GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN date(substr(cfor, 1, 4) || '-' || substr(cfor, 5, 2) || '-' || substr(cfor, 7, 2))
         WHEN cfor GLOB '[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9]*' THEN date(replace(substr(cfor, 1, 10), '/', '-')) END AS corr_day
  FROM p
)
SELECT rk,
  lower(payment_id) AS pid,
  CASE WHEN upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]' THEN upper(merchant_id)
       WHEN merchant_id NOT GLOB '*[^0-9]*' AND length(merchant_id) BETWEEN 1 AND 6 THEN 'M' || substr('000000' || merchant_id, -6)
       ELSE upper(merchant_id) END AS mid,
  CASE lower(status)
    WHEN 'authorized' THEN 'authorized' WHEN 'authorised' THEN 'authorized'
    WHEN 'captured' THEN 'captured' WHEN 'failed' THEN 'failed'
    WHEN 'voided' THEN 'voided' WHEN 'disputed' THEN 'disputed' END AS status_n,
  CASE WHEN amount GLOB '*[0-9]*' AND amount NOT GLOB '*[^0-9.-]*' AND amount NOT GLOB '?*-*' AND amount NOT GLOB '*.*.*' THEN amount END AS amt,
  CASE WHEN settled GLOB '*[0-9]*' AND settled NOT GLOB '*[^0-9.-]*' AND settled NOT GLOB '?*-*' AND settled NOT GLOB '*.*.*' THEN settled END AS stl,
  CASE WHEN upper(currency) GLOB '[A-Z][A-Z][A-Z]' THEN upper(currency) END AS cur,
  CASE WHEN created_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN created_ts END AS created_ts,
  CASE WHEN captured_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN captured_ts END AS captured_ts,
  CASE WHEN updated_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN updated_ts END AS updated_ts,
  CASE WHEN loaded_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN loaded_ts END AS loaded_ts,
  CASE WHEN order_ref <> '' AND lower(order_ref) NOT IN ('null', 'none') THEN order_ref END AS order_ref,
  batch_day,
  coalesce(corr_day, batch_day,
           date(CASE WHEN loaded_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN loaded_ts END, '-1 day')) AS eff_day
FROM d;
 
-- task: fx_history
WITH c AS (
  SELECT
    quote(rate_date)||'|'||quote(currency)||'|'||quote(usd_rate)||'|'||quote(_batch_id)||'|'||quote(_loaded_at) AS rk,
    CASE WHEN lower(trim(rate_date, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(rate_date, ' '||char(9,10,13)) END AS rd,
    CASE WHEN lower(trim(currency, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(currency, ' '||char(9,10,13)) END AS currency,
    CASE WHEN lower(trim(usd_rate, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE replace(trim(usd_rate, ' '||char(9,10,13)), ',', '.') END AS rate,
    CASE WHEN lower(trim(_batch_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid,
    CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL
         ELSE trim(replace(replace(replace(replace(replace(upper(trim(_loaded_at, ' '||char(9,10,13))),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) END AS lo
  FROM raw_fx_rates
),
p AS (
  SELECT rk,
    CASE WHEN upper(currency) GLOB '[A-Z][A-Z][A-Z]' THEN upper(currency) END AS cur,
    coalesce(
      CASE WHEN rd GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(rd, 1, 10))
           WHEN rd GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN date(substr(rd, 1, 4) || '-' || substr(rd, 5, 2) || '-' || substr(rd, 7, 2))
           WHEN rd GLOB '[0-9][0-9][0-9][0-9]/[0-9][0-9]/[0-9][0-9]*' THEN date(replace(substr(rd, 1, 10), '/', '-')) END,
      CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid, 1, 10))
           WHEN bid GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN date(substr(bid, 1, 4) || '-' || substr(bid, 5, 2) || '-' || substr(bid, 7, 2)) END
    ) AS rate_day,
    CASE WHEN rate GLOB '*[0-9]*' AND rate NOT GLOB '*[^0-9.]*' AND rate NOT GLOB '*.*.*' AND CAST(rate AS REAL) > 0 THEN CAST(rate AS REAL) END AS rate,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL) / 1000.0, 'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL), 'unixepoch') END
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9]' THEN datetime(lo || ':00')
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(lo, 1, length(lo) - 2) || ':' || substr(lo, -2))
      ELSE datetime(lo) END AS loaded_ts
  FROM c
)
SELECT rk, cur, rate_day, rate, loaded_ts FROM p;
 
-- task: merchants_history
WITH c AS (
  SELECT
    quote(merchant_id)||'|'||quote(name)||'|'||quote(country)||'|'||quote(is_test)||'|'||quote(_batch_id)||'|'||quote(_loaded_at) AS rk,
    CASE WHEN lower(trim(merchant_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(merchant_id, ' '||char(9,10,13)) END AS merchant_id,
    upper(trim(country, ' '||char(9,10,13))) AS country,
    lower(trim(is_test, ' '||char(9,10,13))) AS is_test,
    CASE WHEN lower(trim(_batch_id, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL ELSE trim(_batch_id, ' '||char(9,10,13)) END AS bid,
    CASE WHEN lower(trim(_loaded_at, ' '||char(9,10,13))) IN ('','\n','null','none','nil','n/a','nan','nat','(null)','<null>','undefined','#n/a','missing','-','--','?') THEN NULL
         ELSE trim(replace(replace(replace(replace(replace(upper(trim(_loaded_at, ' '||char(9,10,13))),' UTC',''),'UTC',''),' GMT',''),'GMT',''),'T',' ')) END AS lo
  FROM raw_merchants
),
p AS (
  SELECT rk,
    CASE WHEN upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]' THEN upper(merchant_id)
         WHEN merchant_id NOT GLOB '*[^0-9]*' AND length(merchant_id) BETWEEN 1 AND 6 THEN 'M' || substr('000000' || merchant_id, -6)
         ELSE upper(merchant_id) END AS mid,
    CASE WHEN country GLOB '[A-Z][A-Z]' THEN country END AS country,
    CASE WHEN is_test IN ('t', 'true', '1', 'y', 'yes') THEN 1 WHEN is_test IN ('f', 'false', '0', 'n', 'no') THEN 0 END AS is_test,
    CASE WHEN bid GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' THEN date(substr(bid, 1, 10))
         WHEN bid GLOB '[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN date(substr(bid, 1, 4) || '-' || substr(bid, 5, 2) || '-' || substr(bid, 7, 2)) END AS bday,
    CASE WHEN lo IS NULL THEN NULL
      WHEN lo NOT GLOB '*[^0-9.]*' THEN CASE WHEN CAST(lo AS REAL) >= 1e11 THEN datetime(CAST(lo AS REAL) / 1000.0, 'unixepoch') WHEN CAST(lo AS REAL) >= 1e8 THEN datetime(CAST(lo AS REAL), 'unixepoch') END
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9]' THEN datetime(lo || ':00')
      WHEN length(lo) > 10 AND lo GLOB '*[+-][0-9][0-9][0-9][0-9]' THEN datetime(substr(lo, 1, length(lo) - 2) || ':' || substr(lo, -2))
      ELSE datetime(lo) END AS loaded_ts
  FROM c
)
SELECT rk, mid, country, is_test, coalesce(bday, date(loaded_ts, '-1 day')) AS batch_day, loaded_ts FROM p;
 
-- task: fct_payments
WITH p AS (
  SELECT *,
    coalesce(eff_day, '0000-00-00') || coalesce(loaded_ts, '0000-00-00 00:00:00') || coalesce(updated_ts, '0000-00-00 00:00:00') AS k
  FROM payments_history
  WHERE pid GLOB 'pay_????????'
),
g AS (
  SELECT pid,
    nullif(substr(max(k || coalesce(status_n, '')), 49), '') AS status,
    substr(max(CASE WHEN amt IS NOT NULL THEN k || amt END), 49) AS amt,
    substr(max(CASE WHEN cur IS NOT NULL THEN k || cur END), 49) AS cur,
    substr(max(CASE WHEN created_ts IS NOT NULL THEN k || created_ts END), 49) AS created_ts,
    substr(max(CASE WHEN mid IS NOT NULL THEN k || mid END), 49) AS mid,
    substr(max(CASE WHEN order_ref IS NOT NULL THEN k || order_ref END), 49) AS order_ref,
    nullif(substr(max(k || coalesce(captured_ts, '')), 49), '') AS cap_last,
    substr(max(CASE WHEN captured_ts IS NOT NULL THEN k || captured_ts END), 49) AS cap_any
  FROM p
  GROUP BY pid
),
sd AS (
  SELECT pid, eff_day,
    substr(max(coalesce(loaded_ts, '0000-00-00 00:00:00') || coalesce(updated_ts, '0000-00-00 00:00:00') || stl), 39) AS stl
  FROM p
  WHERE stl IS NOT NULL
  GROUP BY pid, eff_day
),
gd AS (
  SELECT g.*,
    CASE WHEN cur IN ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') THEN 1.0
         WHEN cur IN ('BHD','IQD','JOD','KWD','LYD','OMR','TND') THEN 1000.0
         ELSE 100.0 END AS dv,
    date(created_ts) AS cday
  FROM g
),
st AS (
  SELECT sd.pid,
    sum(CASE WHEN instr(sd.stl, '.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END) AS st_all,
    sum(CASE WHEN sd.eff_day BETWEEN '2026-02-02' AND '2026-02-26' THEN
      CASE WHEN instr(sd.stl, '.') > 0 THEN round(CAST(sd.stl AS REAL) * gd.dv) ELSE CAST(sd.stl AS REAL) END ELSE 0 END) AS st_in
  FROM sd JOIN gd ON gd.pid = sd.pid
  GROUP BY sd.pid
),
fx1 AS (
  SELECT cur, rate_day, rate FROM (
    SELECT cur, rate_day, rate,
      row_number() OVER (PARTITION BY cur, rate_day ORDER BY loaded_ts DESC, rk DESC) AS rn
    FROM fx_history
    WHERE cur IS NOT NULL AND rate_day IS NOT NULL AND rate > 0
  ) WHERE rn = 1
),
fxm AS (
  SELECT cur, rate AS med FROM (
    SELECT cur, rate, row_number() OVER (PARTITION BY cur ORDER BY rate) AS rn, count(*) OVER (PARTITION BY cur) AS n
    FROM fx1
  ) WHERE rn = (n + 1) / 2
),
fx2 AS (
  SELECT f.cur, f.rate_day,
    CASE WHEN f.rate / m.med BETWEEN 0.9 AND 1.11 THEN f.rate
         WHEN (1.0 / f.rate) / m.med BETWEEN 0.9 AND 1.11 THEN 1.0 / f.rate END AS rate
  FROM fx1 f JOIN fxm m ON m.cur = f.cur
),
fx3 AS (
  SELECT cur, rate_day, rate, lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day
  FROM fx2 WHERE rate IS NOT NULL
),
m1 AS (
  SELECT mid, batch_day, country, is_test FROM (
    SELECT mid, batch_day, country, is_test,
      row_number() OVER (PARTITION BY mid, batch_day ORDER BY loaded_ts DESC, rk DESC) AS rn
    FROM merchants_history
    WHERE mid IS NOT NULL AND batch_day IS NOT NULL
  ) WHERE rn = 1
),
mc AS (
  SELECT mid, batch_day, country, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1 WHERE country IS NOT NULL
),
mt AS (
  SELECT mid, batch_day, is_test, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1 WHERE is_test IS NOT NULL
),
mf AS (
  SELECT mid,
    count(DISTINCT country) AS n_country,
    substr(min(CASE WHEN country IS NOT NULL THEN batch_day || country END), 11) AS first_country,
    CAST(substr(min(CASE WHEN is_test IS NOT NULL THEN batch_day || is_test END), 11) AS INTEGER) AS first_test
  FROM m1 GROUP BY mid
),
j AS (
  SELECT gd.*,
    coalesce(fx3.rate, CASE WHEN gd.cur = 'USD' THEN 1.0 END) AS rate,
    coalesce(mc.country, CASE WHEN mf.n_country = 1 THEN mf.first_country END) AS country,
    coalesce(mt.is_test, mf.first_test, 0) AS is_test,
    coalesce(st.st_all, 0) AS st_all,
    coalesce(st.st_in, 0) AS st_in
  FROM gd
  LEFT JOIN fx3 ON fx3.cur = gd.cur AND gd.cday >= fx3.rate_day AND (fx3.next_day IS NULL OR gd.cday < fx3.next_day)
  LEFT JOIN mc ON mc.mid = gd.mid AND gd.cday >= mc.batch_day AND (mc.next_day IS NULL OR gd.cday < mc.next_day)
  LEFT JOIN mt ON mt.mid = gd.mid AND gd.cday >= mt.batch_day AND (mt.next_day IS NULL OR gd.cday < mt.next_day)
  LEFT JOIN mf ON mf.mid = gd.mid
  LEFT JOIN st ON st.pid = gd.pid
),
v AS (
  SELECT j.*,
    CASE WHEN amt IS NULL THEN NULL WHEN instr(amt, '.') > 0 THEN CAST(amt AS REAL) ELSE CAST(amt AS REAL) / dv END * rate AS amount_raw,
    st_all / dv * rate AS settled_raw,
    st_in / dv * rate AS in_raw
  FROM j
)
SELECT pid AS payment_id,
  status,
  round(amount_raw + CASE WHEN amount_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS amount_usd,
  round(settled_raw + CASE WHEN settled_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS settled_usd,
  round(in_raw + CASE WHEN in_raw < 0 THEN -1e-9 ELSE 1e-9 END, 2) AS settled_in_period_usd,
  replace(CASE WHEN cap_last IS NOT NULL THEN cap_last
               WHEN status IN ('captured', 'disputed') THEN cap_any END, ' ', 'T') || 'Z' AS captured_at,
  order_ref,
  country AS merchant_country
FROM v
WHERE is_test = 0;
