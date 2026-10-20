/* Claude_gold_submit_Postgres.sql
   PostgreSQL 16+ port of gold_submit.sql (the top-1 submission, written for SQLite).
   Same DAG, same logic, same task order. Only the dialect changed.

   Assumptions
   - raw_payments, raw_fx_rates, raw_merchants exist and every column is TEXT (a text dump landed as-is).
   - PostgreSQL 16 or newer: pg_input_is_valid() is used so a bad value becomes NULL instead of an error
     (SQLite's datetime()/date()/json_valid() return NULL on bad input, Postgres casts raise).
   - Money is NUMERIC, not float, so the "+/- 1e-9" rounding nudge of the SQLite version is not needed.
   - Period dates for settled_in_period_usd are copied from the gold file (see `params` in fct_payments).

   SQLite -> Postgres cheat sheet
     quote(x)                        -> quote_nullable(x)
     trim(x, chars)                  -> btrim(x, chars)        char(9,10,13) -> E'\t\n\r'
     x GLOB '[0-9][0-9]*'            -> x ~ '^[0-9]{2}'        (regex instead of glob)
     instr(a, b)                     -> strpos(a, b)
     datetime(x) / date(x)           -> dd_ts(x) / dd_day(x)   (helpers below, never raise)
     datetime(n, 'unixepoch')        -> to_timestamp(n) AT TIME ZONE 'UTC'
     json_extract / json_type        -> jsonb ->, ->>, jsonb_typeof
     max(k || v) + substr trick      -> (array_agg(v ORDER BY k DESC))[1]
     ORDER BY x DESC (NULL smallest) -> ORDER BY x DESC NULLS LAST   (Postgres puts NULL first on DESC)
     median via row_number           -> percentile_disc(0.5) WITHIN GROUP (ORDER BY ...)

dag.yml
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
-- setup: helper functions (run once)
-- ============================================================

-- Trim whitespace and turn every "spelling of nothing" into NULL.
CREATE OR REPLACE FUNCTION dd_null(s text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN lower(btrim(s, E' \t\n\r')) = ANY (ARRAY['', '\n', 'null', 'none', 'nil', 'n/a', 'nan', 'nat',
         '(null)', '<null>', 'undefined', '#n/a', 'missing', '-', '--', '?'])
    THEN NULL
    ELSE btrim(s, E' \t\n\r')
  END
$$;

-- Merchant id: 'm000123' / '123' -> 'M000123'.
CREATE OR REPLACE FUNCTION dd_mid(s text) RETURNS text
LANGUAGE sql IMMUTABLE AS $$
  SELECT CASE
    WHEN upper(s) ~ '^M[0-9]{6}$' THEN upper(s)
    WHEN s ~ '^[0-9]{1,6}$' THEN 'M' || lpad(s, 6, '0')
    ELSE upper(s)
  END
$$;

-- Calendar day from 'YYYY-MM-DD...', 'YYYYMMDD' or (optionally) 'YYYY/MM/DD...'. Bad value -> NULL.
CREATE OR REPLACE FUNCTION dd_day(s text, allow_slash boolean DEFAULT true) RETURNS date
LANGUAGE sql STABLE AS $$
  SELECT CASE
    WHEN s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}' THEN
      CASE WHEN pg_input_is_valid(left(s, 10), 'date') THEN left(s, 10)::date END
    WHEN s ~ '^[0-9]{8}$' THEN
      CASE WHEN pg_input_is_valid(left(s, 4) || '-' || substr(s, 5, 2) || '-' || substr(s, 7, 2), 'date')
           THEN (left(s, 4) || '-' || substr(s, 5, 2) || '-' || substr(s, 7, 2))::date END
    WHEN allow_slash AND s ~ '^[0-9]{4}/[0-9]{2}/[0-9]{2}' THEN
      CASE WHEN pg_input_is_valid(replace(left(s, 10), '/', '-'), 'date')
           THEN replace(left(s, 10), '/', '-')::date END
  END
$$;

-- Any of: epoch seconds, epoch millis, 'YYYY-MM-DD[ HH:MM[:SS[.f]]][ ][+HH|+HH:MM|+HHMM|Z]', with
-- 'T' / 'UTC' / 'GMT' noise. Result is a UTC wall-clock TIMESTAMP truncated to the second.
-- No offset = already UTC. Anything else -> NULL.
CREATE OR REPLACE FUNCTION dd_ts(raw text) RETURNS timestamp
LANGUAGE sql STABLE AS $$
  WITH n AS (
    SELECT btrim(replace(replace(replace(replace(replace(upper(raw), ' UTC', ''), 'UTC', ''), ' GMT', ''), 'GMT', ''), 'T', ' ')) AS s
  )
  SELECT date_trunc('second', CASE
    WHEN s IS NULL OR s = '' THEN NULL
    -- digits only: an epoch count. >= 1e11 is millis, >= 1e8 is seconds, anything smaller is not a time
    WHEN s ~ '^([0-9]+\.?[0-9]*|\.[0-9]+)$' THEN
      CASE WHEN s::numeric >= 1e11 AND s::numeric < 2.5e14 THEN to_timestamp((s::numeric / 1000.0)::double precision) AT TIME ZONE 'UTC'
           WHEN s::numeric >= 1e8  AND s::numeric < 1e11   THEN to_timestamp(s::double precision) AT TIME ZONE 'UTC'
      END
    -- only accept an ISO-like shape (Postgres would also accept words like 'now' or 'today')
    WHEN s !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}( [0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?( ?([+-][0-9]{2}(:?[0-9]{2})?|Z))?)?$' THEN NULL
    -- has an offset: convert to UTC
    WHEN s ~ ' [0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)? ?([+-][0-9]{2}(:?[0-9]{2})?|Z)$' THEN
      CASE WHEN pg_input_is_valid(s, 'timestamptz') THEN s::timestamptz AT TIME ZONE 'UTC' END
    -- no offset: already UTC
    ELSE
      CASE WHEN pg_input_is_valid(s, 'timestamp') THEN s::timestamp END
  END)
  FROM n
$$;

-- ============================================================
-- task: payments_history
-- ============================================================
WITH c AS (
  SELECT
    quote_nullable(payment_id) || '|' || quote_nullable(_batch_id) || '|' || quote_nullable(_correction_for) || '|' ||
    quote_nullable(_loaded_at) || '|' || quote_nullable(updated_at) || '|' || quote_nullable(status) || '|' ||
    quote_nullable(settled) || '|' || quote_nullable(captured_at) || '|' || quote_nullable(amount) || '|' ||
    quote_nullable(currency) || '|' || quote_nullable(merchant_id) AS rk,
    dd_null(payment_id)  AS payment_id,
    dd_null(merchant_id) AS merchant_id,
    dd_null(amount)      AS amount,
    dd_null(currency)    AS currency,
    dd_null(status)      AS status,
    dd_null(settled)     AS settled,
    dd_null(created_at)  AS created_at,
    dd_null(captured_at) AS captured_at,
    dd_null(updated_at)  AS updated_at,
    dd_null(metadata)    AS metadata,
    dd_null(_batch_id)   AS bid,
    dd_null(_correction_for) AS cfor,
    dd_null(_loaded_at)  AS lat
  FROM raw_payments
),
t AS (
  SELECT c.*,
    -- metadata as jsonb; a JSON string that itself holds JSON (double encoded) is unwrapped once
    CASE WHEN pg_input_is_valid(metadata, 'jsonb') THEN
      CASE WHEN jsonb_typeof(metadata::jsonb) = 'string' AND pg_input_is_valid(metadata::jsonb #>> '{}', 'jsonb')
           THEN (metadata::jsonb #>> '{}')::jsonb
           ELSE metadata::jsonb END
    END AS mj,
    -- metadata cut at the column width is not JSON: look for the text after "order_ref"
    CASE WHEN strpos(metadata, '"order_ref"') > 0
         THEN ltrim(substr(metadata, strpos(metadata, '"order_ref"') + 11), ' :') END AS mrest
  FROM c
),
p AS (
  SELECT rk, payment_id, merchant_id, amount, currency, status, settled, bid, cfor,
    dd_ts(created_at)  AS created_ts,
    dd_ts(captured_at) AS captured_ts,
    dd_ts(updated_at)  AS updated_ts,
    dd_ts(lat)         AS loaded_ts,
    CASE
      WHEN mj IS NOT NULL THEN
        CASE WHEN jsonb_typeof(mj) = 'object' AND jsonb_typeof(mj -> 'order_ref') IN ('string', 'number')
             THEN btrim(mj ->> 'order_ref') END
      WHEN mrest IS NOT NULL THEN
        CASE WHEN substr(mrest, 1, 1) = '"' THEN
               CASE WHEN strpos(substr(mrest, 2), '"') > 0
                    THEN btrim(substr(mrest, 2, strpos(substr(mrest, 2), '"') - 1)) END
             WHEN strpos(mrest, ',') > 0 THEN btrim(substr(mrest, 1, strpos(mrest, ',') - 1))
             WHEN strpos(mrest, '}') > 0 THEN btrim(substr(mrest, 1, strpos(mrest, '}') - 1))
        END
    END AS order_ref
  FROM t
),
d AS (
  SELECT p.*,
    dd_day(bid)  AS batch_day,
    dd_day(cfor) AS corr_day
  FROM p
)
SELECT rk,
  lower(payment_id) AS pid,
  dd_mid(merchant_id) AS mid,
  CASE lower(status)
    WHEN 'authorized' THEN 'authorized' WHEN 'authorised' THEN 'authorized'
    WHEN 'captured' THEN 'captured' WHEN 'failed' THEN 'failed'
    WHEN 'voided' THEN 'voided' WHEN 'disputed' THEN 'disputed' END AS status_n,
  -- amount / settled: one optional '-' at the start, digits, at most one '.'
  CASE WHEN amount  ~ '^-?([0-9]+\.?[0-9]*|\.[0-9]+)$' THEN amount  END AS amt,
  CASE WHEN settled ~ '^-?([0-9]+\.?[0-9]*|\.[0-9]+)$' THEN settled END AS stl,
  CASE WHEN upper(currency) ~ '^[A-Z]{3}$' THEN upper(currency) END AS cur,
  CASE WHEN created_ts  BETWEEN '1990-01-01' AND '2100-01-01' THEN created_ts  END AS created_ts,
  CASE WHEN captured_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN captured_ts END AS captured_ts,
  CASE WHEN updated_ts  BETWEEN '1990-01-01' AND '2100-01-01' THEN updated_ts  END AS updated_ts,
  CASE WHEN loaded_ts   BETWEEN '1990-01-01' AND '2100-01-01' THEN loaded_ts   END AS loaded_ts,
  CASE WHEN order_ref <> '' AND lower(order_ref) NOT IN ('null', 'none') THEN order_ref END AS order_ref,
  batch_day,
  -- the day the state belongs to: correction day, else batch day, else the day before it landed
  coalesce(corr_day, batch_day,
           (CASE WHEN loaded_ts BETWEEN '1990-01-01' AND '2100-01-01' THEN loaded_ts END - interval '1 day')::date) AS eff_day
FROM d;

-- ============================================================
-- task: fx_history
-- ============================================================
WITH c AS (
  SELECT
    quote_nullable(rate_date) || '|' || quote_nullable(currency) || '|' || quote_nullable(usd_rate) || '|' ||
    quote_nullable(_batch_id) || '|' || quote_nullable(_loaded_at) AS rk,
    dd_null(rate_date) AS rd,
    dd_null(currency)  AS currency,
    replace(dd_null(usd_rate), ',', '.') AS rate,      -- decimal commas from EU feeds
    dd_null(_batch_id) AS bid,
    dd_null(_loaded_at) AS lo
  FROM raw_fx_rates
),
p AS (
  SELECT rk,
    CASE WHEN upper(currency) ~ '^[A-Z]{3}$' THEN upper(currency) END AS cur,
    coalesce(dd_day(rd), dd_day(bid, false)) AS rate_day,
    CASE WHEN rate ~ '^([0-9]+\.?[0-9]*|\.[0-9]+)$'
         THEN CASE WHEN rate::numeric > 0 THEN rate::numeric END END AS rate,
    dd_ts(lo) AS loaded_ts
  FROM c
)
SELECT rk, cur, rate_day, rate, loaded_ts FROM p;

-- ============================================================
-- task: merchants_history
-- ============================================================
WITH c AS (
  SELECT
    quote_nullable(merchant_id) || '|' || quote_nullable(name) || '|' || quote_nullable(country) || '|' ||
    quote_nullable(is_test) || '|' || quote_nullable(_batch_id) || '|' || quote_nullable(_loaded_at) AS rk,
    dd_null(merchant_id) AS merchant_id,
    upper(btrim(country, E' \t\n\r')) AS country,
    lower(btrim(is_test, E' \t\n\r')) AS is_test,
    dd_null(_batch_id)   AS bid,
    dd_null(_loaded_at)  AS lo
  FROM raw_merchants
),
p AS (
  SELECT rk,
    dd_mid(merchant_id) AS mid,
    CASE WHEN country ~ '^[A-Z]{2}$' THEN country END AS country,
    CASE WHEN is_test IN ('t', 'true', '1', 'y', 'yes') THEN 1
         WHEN is_test IN ('f', 'false', '0', 'n', 'no') THEN 0 END AS is_test,
    dd_day(bid, false) AS bday,
    dd_ts(lo) AS loaded_ts
  FROM c
)
SELECT rk, mid, country, is_test,
  coalesce(bday, (loaded_ts - interval '1 day')::date) AS batch_day,
  loaded_ts
FROM p;

-- ============================================================
-- task: fct_payments
-- ============================================================
WITH params AS (
  -- copied from gold_submit.sql; the Week 5 README closes through 2026-10-12, change these if you want that window
  SELECT DATE '2026-02-02' AS period_start, DATE '2026-02-26' AS period_end
),
p AS (
  SELECT *,
    -- sort key: newest state first, missing values last
    coalesce(eff_day,    DATE '0001-01-01')      AS k_day,
    coalesce(loaded_ts,  TIMESTAMP '0001-01-01') AS k_load,
    coalesce(updated_ts, TIMESTAMP '0001-01-01') AS k_upd
  FROM payments_history
  WHERE pid ~ '^pay_.{8}$'
),
g AS (
  -- 1 row per payment. status / cap_last come from the newest row as-is;
  -- every other field is the newest NON-NULL value (the newest row often lacks older fields).
  SELECT pid,
    (array_agg(status_n   ORDER BY k_day DESC, k_load DESC, k_upd DESC, status_n   DESC NULLS LAST))[1] AS status,
    (array_agg(amt        ORDER BY k_day DESC, k_load DESC, k_upd DESC, amt COLLATE "C" DESC)        FILTER (WHERE amt IS NOT NULL))[1]        AS amt,
    (array_agg(cur        ORDER BY k_day DESC, k_load DESC, k_upd DESC, cur DESC)                    FILTER (WHERE cur IS NOT NULL))[1]        AS cur,
    (array_agg(created_ts ORDER BY k_day DESC, k_load DESC, k_upd DESC, created_ts DESC)             FILTER (WHERE created_ts IS NOT NULL))[1] AS created_ts,
    (array_agg(mid        ORDER BY k_day DESC, k_load DESC, k_upd DESC, mid DESC)                    FILTER (WHERE mid IS NOT NULL))[1]        AS mid,
    (array_agg(order_ref  ORDER BY k_day DESC, k_load DESC, k_upd DESC, order_ref COLLATE "C" DESC)  FILTER (WHERE order_ref IS NOT NULL))[1]  AS order_ref,
    (array_agg(captured_ts ORDER BY k_day DESC, k_load DESC, k_upd DESC, captured_ts DESC NULLS LAST))[1] AS cap_last,
    (array_agg(captured_ts ORDER BY k_day DESC, k_load DESC, k_upd DESC, captured_ts DESC)           FILTER (WHERE captured_ts IS NOT NULL))[1] AS cap_any
  FROM p
  GROUP BY pid
),
sd AS (
  -- settled movement: 1 value per payment per day (a restated day replaces, it does not add)
  SELECT pid, eff_day,
    (array_agg(stl ORDER BY k_load DESC, k_upd DESC, stl COLLATE "C" DESC))[1] AS stl
  FROM p
  WHERE stl IS NOT NULL
  GROUP BY pid, eff_day
),
gd AS (
  SELECT g.*,
    -- minor units per major unit: 0-decimal, 3-decimal, else 2-decimal currencies
    CASE WHEN cur IN ('BIF','CLP','DJF','GNF','ISK','JPY','KMF','KRW','PYG','RWF','UGX','UYI','VND','VUV','XAF','XOF','XPF') THEN 1.0
         WHEN cur IN ('BHD','IQD','JOD','KWD','LYD','OMR','TND') THEN 1000.0
         ELSE 100.0 END AS dv,
    created_ts::date AS cday
  FROM g
),
st AS (
  -- a value with a '.' is in major units (old code path): convert to minor units before summing
  SELECT sd.pid,
    sum(CASE WHEN strpos(sd.stl, '.') > 0 THEN round(sd.stl::numeric * gd.dv) ELSE sd.stl::numeric END) AS st_all,
    sum(CASE WHEN sd.eff_day BETWEEN pr.period_start AND pr.period_end
             THEN CASE WHEN strpos(sd.stl, '.') > 0 THEN round(sd.stl::numeric * gd.dv) ELSE sd.stl::numeric END
             ELSE 0 END) AS st_in
  FROM sd
  JOIN gd ON gd.pid = sd.pid
  CROSS JOIN params pr
  GROUP BY sd.pid
),
fx1 AS (
  -- 1 rate per currency per day: the latest published (a wrong rate is re-published later)
  SELECT cur, rate_day, rate FROM (
    SELECT cur, rate_day, rate,
      row_number() OVER (PARTITION BY cur, rate_day ORDER BY loaded_ts DESC NULLS LAST, rk COLLATE "C" DESC) AS rn
    FROM fx_history
    WHERE cur IS NOT NULL AND rate_day IS NOT NULL AND rate > 0
  ) x
  WHERE rn = 1
),
fxm AS (
  SELECT cur, percentile_disc(0.5) WITHIN GROUP (ORDER BY rate) AS med
  FROM fx1
  GROUP BY cur
),
fx2 AS (
  -- keep a rate near the currency's median; a rate near 1/median was published inverted: flip it back
  SELECT f.cur, f.rate_day,
    CASE WHEN f.rate / m.med BETWEEN 0.9 AND 1.11 THEN f.rate
         WHEN (1.0 / f.rate) / m.med BETWEEN 0.9 AND 1.11 THEN 1.0 / f.rate END AS rate
  FROM fx1 f
  JOIN fxm m ON m.cur = f.cur
),
fx3 AS (
  -- validity window of each rate: from its day until the next published day (weekends use Friday's rate)
  SELECT cur, rate_day, rate, lead(rate_day) OVER (PARTITION BY cur ORDER BY rate_day) AS next_day
  FROM fx2
  WHERE rate IS NOT NULL
),
m1 AS (
  SELECT mid, batch_day, country, is_test FROM (
    SELECT mid, batch_day, country, is_test,
      row_number() OVER (PARTITION BY mid, batch_day ORDER BY loaded_ts DESC NULLS LAST, rk COLLATE "C" DESC) AS rn
    FROM merchants_history
    WHERE mid IS NOT NULL AND batch_day IS NOT NULL
  ) x
  WHERE rn = 1
),
mc AS (
  SELECT mid, batch_day, country, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1
  WHERE country IS NOT NULL
),
mt AS (
  SELECT mid, batch_day, is_test, lead(batch_day) OVER (PARTITION BY mid ORDER BY batch_day) AS next_day
  FROM m1
  WHERE is_test IS NOT NULL
),
mf AS (
  -- fallbacks: the merchant's earliest known country (only if it never moved) and earliest test flag
  SELECT mid,
    count(DISTINCT country) AS n_country,
    (array_agg(country ORDER BY batch_day) FILTER (WHERE country IS NOT NULL))[1] AS first_country,
    (array_agg(is_test ORDER BY batch_day) FILTER (WHERE is_test IS NOT NULL))[1] AS first_test
  FROM m1
  GROUP BY mid
),
j AS (
  SELECT gd.*,
    coalesce(fx3.rate, CASE WHEN gd.cur = 'USD' THEN 1.0 END) AS rate,
    coalesce(mc.country, CASE WHEN mf.n_country = 1 THEN mf.first_country END) AS country,
    coalesce(mt.is_test, mf.first_test, 0) AS is_test,
    coalesce(st.st_all, 0) AS st_all,
    coalesce(st.st_in, 0)  AS st_in
  FROM gd
  LEFT JOIN fx3 ON fx3.cur = gd.cur AND gd.cday >= fx3.rate_day AND (fx3.next_day IS NULL OR gd.cday < fx3.next_day)
  LEFT JOIN mc  ON mc.mid  = gd.mid AND gd.cday >= mc.batch_day AND (mc.next_day  IS NULL OR gd.cday < mc.next_day)
  LEFT JOIN mt  ON mt.mid  = gd.mid AND gd.cday >= mt.batch_day AND (mt.next_day  IS NULL OR gd.cday < mt.next_day)
  LEFT JOIN mf  ON mf.mid  = gd.mid
  LEFT JOIN st  ON st.pid  = gd.pid
),
v AS (
  SELECT j.*,
    -- amount with a '.' is major units, otherwise minor units
    (CASE WHEN amt IS NULL THEN NULL
          WHEN strpos(amt, '.') > 0 THEN amt::numeric
          ELSE amt::numeric / dv END) * rate AS amount_raw,
    st_all / dv * rate AS settled_raw,
    st_in  / dv * rate AS in_raw
  FROM j
)
SELECT pid AS payment_id,
  status,
  round(amount_raw, 2) AS amount_usd,
  round(settled_raw, 2) AS settled_usd,
  round(in_raw, 2) AS settled_in_period_usd,
  to_char(CASE WHEN cap_last IS NOT NULL THEN cap_last
               WHEN status IN ('captured', 'disputed') THEN cap_any END,
          'YYYY-MM-DD"T"HH24:MI:SS"Z"') AS captured_at,
  order_ref,
  country AS merchant_country
FROM v
WHERE is_test = 0;

-- ============================================================
-- how to run it on Postgres (outside the DAG engine)
--   CREATE TABLE payments_history   AS <payments_history select>;
--   CREATE TABLE fx_history         AS <fx_history select>;
--   CREATE TABLE merchants_history  AS <merchants_history select>;
--   CREATE TABLE fct_payments       AS <fct_payments select>;
--
-- "incremental, merge on rk" = keep the history across nights and add only new rows:
--   CREATE UNIQUE INDEX ON payments_history (rk);
--   INSERT INTO payments_history <payments_history select> ON CONFLICT (rk) DO NOTHING;
-- (rk is the whole raw row, so a matching rk is an identical row and nothing needs updating.)
-- ============================================================
