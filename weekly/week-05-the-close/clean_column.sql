/* dag.yml
dag: the_close
schedule: "0 3,9,15,21 * * *"
catchup: true
tasks:
  currency_units:
    materialized: view
  payments_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [payment_id, effective_day]
    depends_on: [raw_payments]
  fx_rates_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [currency, rate_date]
    depends_on: [raw_fx_rates]
  merchants_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [merchant_id, snapshot_day]
    depends_on: [raw_merchants]
  fx_intervals:
    materialized: view
    schedule: "0 3 * * *"
    trigger_rule: none_failed
    depends_on: [fx_rates_history]
  merchant_intervals:
    materialized: view
    schedule: "0 3 * * *"
    trigger_rule: none_failed
    depends_on: [merchants_history]
  payment_states:
    materialized: view
    schedule: "0 3 * * *"
    trigger_rule: none_failed
    depends_on: [payments_history]
  fct_payments:
    materialized: view
    schedule: "0 3 * * *"
    depends_on: [payment_states, fx_intervals, merchant_intervals, currency_units]
*/
 
-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after
 
-- task: payments_history
WITH ph_source AS (
  -- Existing raw columns come first and keep their names. SQLite suffixes
  -- duplicate fallback names. A missing column therefore reads as NULL;
  -- real source values, including correction dates, remain authoritative.
  SELECT raw_payments.*,
         NULL AS payment_id,
         NULL AS merchant_id,
         NULL AS amount,
         NULL AS currency,
         NULL AS status,
         NULL AS settled,
         NULL AS created_at,
         NULL AS captured_at,
         NULL AS updated_at,
         NULL AS metadata,
         NULL AS _batch_id,
         NULL AS _correction_for,
         NULL AS _loaded_at
  FROM raw_payments
), ph_cleaned AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(src.payment_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.payment_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS payment_id,
         CASE WHEN lower(trim(CAST(src.merchant_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.merchant_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS merchant_id,
         CASE WHEN lower(trim(CAST(src.amount AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.amount AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS amount,
         CASE WHEN lower(trim(CAST(src.currency AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.currency AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS currency,
         CASE WHEN lower(trim(CAST(src.status AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.status AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS status,
         CASE WHEN lower(trim(CAST(src.settled AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.settled AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS settled_text,
         CASE WHEN lower(trim(CAST(src.created_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.created_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS created_at,
         CASE WHEN lower(trim(CAST(src.captured_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.captured_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS captured_at,
         CASE WHEN lower(trim(CAST(src.updated_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.updated_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS updated_at,
         CASE WHEN lower(trim(CAST(src.metadata AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src.metadata AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS metadata,
         CASE WHEN lower(trim(CAST(src._batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(src._correction_for AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._correction_for AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _correction_for,
         CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _loaded_at
  FROM ph_source AS src
  {% if is_incremental() %}
  WHERE strftime('%H','{{ ts }}')='03'
     OR coalesce(julianday(CASE
      WHEN CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END GLOB '*[+-][0-9][0-9]' THEN CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END || ':00'
      WHEN CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END, 1, length(CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END) - 2) || ':' || substr(CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END, -2)
      ELSE CASE WHEN lower(trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(src._loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END END),julianday(substr(_batch_id,1,10)))
          >= coalesce((SELECT max(loaded_ord) FROM {{ this }}),0)-0.000001
  {% endif %}
), ph_typed AS MATERIALIZED (
  SELECT lower(payment_id) AS payment_id,
         CASE WHEN upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]' THEN upper(merchant_id) END AS merchant_id,
         CASE WHEN amount IS NULL THEN NULL
      WHEN length(CASE WHEN substr(amount,1,1) IN ('+','-') THEN substr(amount,2) ELSE amount END) > 0 AND (CASE WHEN substr(amount,1,1) IN ('+','-') THEN substr(amount,2) ELSE amount END) NOT GLOB '*[^0-9]*'
        THEN CAST(amount AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(amount,1,1) = '+' THEN substr(amount,2) ELSE amount END)
        THEN CASE WHEN json_type(CASE WHEN substr(amount,1,1) = '+' THEN substr(amount,2) ELSE amount END)
                       IN ('integer','real') THEN CAST(amount AS NUMERIC) END
      ELSE NULL END AS amount_minor,
         upper(currency) AS currency,
         CASE WHEN lower(status) IN ('authorized','authorised','authorize','authorise','auth','auth_only','authorization') THEN 'authorized' WHEN lower(status) IN ('captured','capture','paid','succeeded','success','settled','completed') THEN 'captured' WHEN lower(status) IN ('failed','failure','declined','decline','error') THEN 'failed' WHEN lower(status) IN ('voided','void','cancelled','canceled','cancel') THEN 'voided' WHEN lower(status) IN ('disputed','dispute','chargeback','charged_back','charged back') THEN 'disputed' END AS status,
         CASE WHEN status IS NOT NULL THEN 1 ELSE 0 END AS status_seen,
         CASE WHEN ph_cleaned.settled_text IS NULL THEN NULL
      WHEN length(CASE WHEN substr(ph_cleaned.settled_text,1,1) IN ('+','-') THEN substr(ph_cleaned.settled_text,2) ELSE ph_cleaned.settled_text END) > 0 AND (CASE WHEN substr(ph_cleaned.settled_text,1,1) IN ('+','-') THEN substr(ph_cleaned.settled_text,2) ELSE ph_cleaned.settled_text END) NOT GLOB '*[^0-9]*'
        THEN CAST(ph_cleaned.settled_text AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(ph_cleaned.settled_text,1,1) = '+' THEN substr(ph_cleaned.settled_text,2) ELSE ph_cleaned.settled_text END)
        THEN CASE WHEN json_type(CASE WHEN substr(ph_cleaned.settled_text,1,1) = '+' THEN substr(ph_cleaned.settled_text,2) ELSE ph_cleaned.settled_text END)
                       IN ('integer','real') THEN CAST(ph_cleaned.settled_text AS NUMERIC) END
      ELSE NULL END AS settled_minor,
         CASE WHEN created_at IS NULL THEN NULL
      WHEN created_at NOT GLOB '*[^0-9]*' AND length(created_at) IN (10, 13, 16)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(created_at AS REAL) /
             CASE length(created_at) WHEN 10 THEN 1 WHEN 13 THEN 1000 ELSE 1000000 END, 'unixepoch')
      WHEN substr(created_at, 1, 10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
       AND date(substr(created_at,1,10),'+0 days')=substr(created_at,1,10)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE
      WHEN created_at GLOB '*[+-][0-9][0-9]' THEN created_at || ':00'
      WHEN created_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(created_at, 1, length(created_at) - 2) || ':' || substr(created_at, -2)
      ELSE created_at END)
      ELSE NULL END AS created_at,
         CASE WHEN captured_at IS NULL THEN NULL
      WHEN captured_at NOT GLOB '*[^0-9]*' AND length(captured_at) IN (10, 13, 16)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(captured_at AS REAL) /
             CASE length(captured_at) WHEN 10 THEN 1 WHEN 13 THEN 1000 ELSE 1000000 END, 'unixepoch')
      WHEN substr(captured_at, 1, 10) GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
       AND date(substr(captured_at,1,10),'+0 days')=substr(captured_at,1,10)
        THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE
      WHEN captured_at GLOB '*[+-][0-9][0-9]' THEN captured_at || ':00'
      WHEN captured_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(captured_at, 1, length(captured_at) - 2) || ':' || substr(captured_at, -2)
      ELSE captured_at END)
      ELSE NULL END AS captured_at,
         CASE WHEN json_valid(metadata) THEN metadata ELSE '{}' END AS metadata,
         date(substr(_batch_id,1,10)) AS source_day,
         coalesce(date(substr(_correction_for,1,10)), date(substr(_batch_id,1,10))) AS effective_day,
         coalesce(julianday(CASE
      WHEN _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at || ':00'
      WHEN _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at, 1, length(_loaded_at) - 2) || ':' || substr(_loaded_at, -2)
      ELSE _loaded_at END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM ph_cleaned
), ph_extracted AS (
  SELECT payment_id, merchant_id, amount_minor, currency, status, status_seen,
         settled_minor, created_at, captured_at,
         CASE WHEN json_type(metadata,'$.order_ref') IN ('text','integer','real','true','false')
              THEN CAST(json_extract(metadata,'$.order_ref') AS TEXT) END AS order_ref,
         CASE WHEN json_type(metadata,'$.order_ref') IS NOT NULL THEN 1 ELSE 0 END AS order_seen,
         source_day,effective_day,loaded_ord
  FROM ph_typed
),
incoming AS (
SELECT payment_id,effective_day,merchant_id,
       CASE WHEN merchant_id IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS merchant_id_ver,
       amount_minor,
       CASE WHEN amount_minor IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS amount_minor_ver,
       currency,
       CASE WHEN currency IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS currency_ver,
       status,
       CASE WHEN status_seen=1 THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS status_ver,
       settled_minor,
       CASE WHEN settled_minor IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS settled_minor_ver,
       created_at,
       CASE WHEN created_at IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS created_at_ver,
       captured_at,
       CASE WHEN captured_at IS NOT NULL THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS captured_at_ver,
       order_ref,
       CASE WHEN order_seen=1 THEN CAST(julianday(source_day) AS INTEGER)*1000000000000 + CAST(round((loaded_ord-2440587.5)*86400000,0) AS INTEGER) END AS order_ref_ver,source_day,loaded_ord FROM ph_extracted
WHERE length(payment_id) = 12 AND payment_id GLOB 'pay_????????'
  AND substr(payment_id,5) NOT GLOB '*[^a-z0-9]*'
  AND effective_day IS NOT NULL AND source_day IS NOT NULL
), candidates AS (
  SELECT payment_id,effective_day,merchant_id,merchant_id_ver,amount_minor,amount_minor_ver,currency,currency_ver,status,status_ver,settled_minor,settled_minor_ver,created_at,created_at_ver,captured_at,captured_at_ver,order_ref,order_ref_ver,source_day,loaded_ord FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.payment_id,h.effective_day,h.merchant_id,h.merchant_id_ver,h.amount_minor,h.amount_minor_ver,h.currency,h.currency_ver,h.status,h.status_ver,h.settled_minor,h.settled_minor_ver,h.created_at,h.created_at_ver,h.captured_at,h.captured_at_ver,h.order_ref,h.order_ref_ver,h.source_day,h.loaded_ord
  FROM {{ this }} AS h
  JOIN (SELECT DISTINCT payment_id,effective_day FROM incoming) AS k
    ON k.payment_id=h.payment_id AND k.effective_day=h.effective_day
  {% endif %}
), grouped AS (
  SELECT payment_id,effective_day,
         max(CASE WHEN merchant_id_ver IS NOT NULL THEN printf('%019d',merchant_id_ver) || char(31) || json_quote(merchant_id) END) AS merchant_id_packed,
         max(CASE WHEN amount_minor_ver IS NOT NULL THEN printf('%019d',amount_minor_ver) || char(31) || json_quote(amount_minor) END) AS amount_minor_packed,
         max(CASE WHEN currency_ver IS NOT NULL THEN printf('%019d',currency_ver) || char(31) || json_quote(currency) END) AS currency_packed,
         max(CASE WHEN status_ver IS NOT NULL THEN printf('%019d',status_ver) || char(31) || json_quote(status) END) AS status_packed,
         max(CASE WHEN settled_minor_ver IS NOT NULL THEN printf('%019d',settled_minor_ver) || char(31) || json_quote(settled_minor) END) AS settled_minor_packed,
         max(CASE WHEN created_at_ver IS NOT NULL THEN printf('%019d',created_at_ver) || char(31) || json_quote(created_at) END) AS created_at_packed,
         max(CASE WHEN captured_at_ver IS NOT NULL THEN printf('%019d',captured_at_ver) || char(31) || json_quote(captured_at) END) AS captured_at_packed,
         max(CASE WHEN order_ref_ver IS NOT NULL THEN printf('%019d',order_ref_ver) || char(31) || json_quote(order_ref) END) AS order_ref_packed,
         max(source_day) AS source_day,max(loaded_ord) AS loaded_ord
  FROM candidates GROUP BY payment_id,effective_day
)
SELECT payment_id,effective_day,
       CASE WHEN json_valid(substr(merchant_id_packed,instr(merchant_id_packed,char(31))+1)) THEN json_extract(substr(merchant_id_packed,instr(merchant_id_packed,char(31))+1),'$') END AS merchant_id,
       CAST(substr(merchant_id_packed,1,instr(merchant_id_packed,char(31))-1) AS INTEGER) AS merchant_id_ver,
       CASE WHEN json_valid(substr(amount_minor_packed,instr(amount_minor_packed,char(31))+1)) THEN json_extract(substr(amount_minor_packed,instr(amount_minor_packed,char(31))+1),'$') END AS amount_minor,
       CAST(substr(amount_minor_packed,1,instr(amount_minor_packed,char(31))-1) AS INTEGER) AS amount_minor_ver,
       CASE WHEN json_valid(substr(currency_packed,instr(currency_packed,char(31))+1)) THEN json_extract(substr(currency_packed,instr(currency_packed,char(31))+1),'$') END AS currency,
       CAST(substr(currency_packed,1,instr(currency_packed,char(31))-1) AS INTEGER) AS currency_ver,
       CASE WHEN json_valid(substr(status_packed,instr(status_packed,char(31))+1)) THEN json_extract(substr(status_packed,instr(status_packed,char(31))+1),'$') END AS status,
       CAST(substr(status_packed,1,instr(status_packed,char(31))-1) AS INTEGER) AS status_ver,
       CASE WHEN json_valid(substr(settled_minor_packed,instr(settled_minor_packed,char(31))+1)) THEN json_extract(substr(settled_minor_packed,instr(settled_minor_packed,char(31))+1),'$') END AS settled_minor,
       CAST(substr(settled_minor_packed,1,instr(settled_minor_packed,char(31))-1) AS INTEGER) AS settled_minor_ver,
       CASE WHEN json_valid(substr(created_at_packed,instr(created_at_packed,char(31))+1)) THEN json_extract(substr(created_at_packed,instr(created_at_packed,char(31))+1),'$') END AS created_at,
       CAST(substr(created_at_packed,1,instr(created_at_packed,char(31))-1) AS INTEGER) AS created_at_ver,
       CASE WHEN json_valid(substr(captured_at_packed,instr(captured_at_packed,char(31))+1)) THEN json_extract(substr(captured_at_packed,instr(captured_at_packed,char(31))+1),'$') END AS captured_at,
       CAST(substr(captured_at_packed,1,instr(captured_at_packed,char(31))-1) AS INTEGER) AS captured_at_ver,
       CASE WHEN json_valid(substr(order_ref_packed,instr(order_ref_packed,char(31))+1)) THEN json_extract(substr(order_ref_packed,instr(order_ref_packed,char(31))+1),'$') END AS order_ref,
       CAST(substr(order_ref_packed,1,instr(order_ref_packed,char(31))-1) AS INTEGER) AS order_ref_ver,source_day,loaded_ord
FROM grouped;
 
-- task: fx_rates_history
WITH incoming AS (WITH cleaned AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(rate_date AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(rate_date AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS rate_date,
         CASE WHEN lower(trim(CAST(currency AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(currency AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS currency,
         CASE WHEN lower(trim(CAST(usd_rate AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(usd_rate AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS usd_rate,
         CASE WHEN lower(trim(CAST(_batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(_batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(_loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(_loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _loaded_at FROM raw_fx_rates
), typed AS MATERIALIZED (
  SELECT date(substr(rate_date,1,10)) AS rate_date, upper(currency) AS currency,
         CASE WHEN usd_rate IS NULL THEN NULL
      WHEN length(CASE WHEN substr(usd_rate,1,1) IN ('+','-') THEN substr(usd_rate,2) ELSE usd_rate END) > 0 AND (CASE WHEN substr(usd_rate,1,1) IN ('+','-') THEN substr(usd_rate,2) ELSE usd_rate END) NOT GLOB '*[^0-9]*'
        THEN CAST(usd_rate AS NUMERIC)
      WHEN json_valid(CASE WHEN substr(usd_rate,1,1) = '+' THEN substr(usd_rate,2) ELSE usd_rate END)
        THEN CASE WHEN json_type(CASE WHEN substr(usd_rate,1,1) = '+' THEN substr(usd_rate,2) ELSE usd_rate END)
                       IN ('integer','real') THEN CAST(usd_rate AS NUMERIC) END
      ELSE NULL END AS rate_value, usd_rate,
         coalesce(julianday(CASE
      WHEN _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at || ':00'
      WHEN _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at, 1, length(_loaded_at) - 2) || ':' || substr(_loaded_at, -2)
      ELSE _loaded_at END),julianday(substr(_batch_id,1,10))) AS loaded_ord
  FROM cleaned
)
SELECT rate_date,currency,rate_value,
       CASE WHEN usd_rate NOT GLOB '*[^0-9.]*' AND length(usd_rate) < 17
              THEN CAST(replace(usd_rate,'.','') AS INTEGER)
            ELSE CAST(round(rate_value*100000000,0) AS INTEGER) END AS rate_num,
       CASE WHEN usd_rate NOT GLOB '*[^0-9.]*' AND length(usd_rate) < 17
              THEN CASE WHEN instr(usd_rate,'.')=0 THEN 1 ELSE CASE length(substr(usd_rate,instr(usd_rate,'.')+1)) WHEN 1 THEN 10 WHEN 2 THEN 100 WHEN 3 THEN 1000 WHEN 4 THEN 10000 WHEN 5 THEN 100000 WHEN 6 THEN 1000000 WHEN 7 THEN 10000000 WHEN 8 THEN 100000000 WHEN 9 THEN 1000000000 END END
            ELSE 100000000 END AS rate_den,
       loaded_ord
FROM typed WHERE rate_date IS NOT NULL AND rate_value > 0), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT currency,rate_date FROM incoming) AS k
    ON h.currency=k.currency AND h.rate_date=k.rate_date
  {% endif %}
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY currency,rate_date ORDER BY loaded_ord DESC) AS rn
  FROM candidates
)
SELECT rate_date,currency,rate_value,rate_num,rate_den,loaded_ord FROM ranked WHERE rn=1;
 
-- task: merchants_history
WITH incoming AS (WITH cleaned AS MATERIALIZED (
  SELECT CASE WHEN lower(trim(CAST(merchant_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(merchant_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS merchant_id,
         CASE WHEN lower(trim(CAST(country AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(country AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS country,
         CASE WHEN lower(trim(CAST(is_test AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(is_test AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS is_test,
         CASE WHEN lower(trim(CAST(_batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(_batch_id AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _batch_id,
         CASE WHEN lower(trim(CAST(_loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160))) IN ('', 'null', 'none', 'nil', 'n/a', 'na', 'nan', 'undefined', '\n', '\\n') THEN NULL ELSE trim(CAST(_loaded_at AS TEXT), ' ' || char(9) || char(10) || char(13) || char(160)) END AS _loaded_at FROM raw_merchants
)
SELECT upper(merchant_id) AS merchant_id,
       CASE WHEN upper(country) GLOB '[A-Z][A-Z]' THEN upper(country) END AS country,
       CASE WHEN lower(is_test) IN ('t','true','1','yes','y') THEN 1
            WHEN lower(is_test) IN ('f','false','0','no','n') THEN 0 END AS is_test,
       date(substr(_batch_id,1,10)) AS snapshot_day,
       coalesce(julianday(CASE
      WHEN _loaded_at GLOB '*[+-][0-9][0-9]' THEN _loaded_at || ':00'
      WHEN _loaded_at GLOB '*[+-][0-9][0-9][0-9][0-9]'
        THEN substr(_loaded_at, 1, length(_loaded_at) - 2) || ':' || substr(_loaded_at, -2)
      ELSE _loaded_at END),julianday(substr(_batch_id,1,10))) AS loaded_ord
FROM cleaned
WHERE upper(merchant_id) GLOB 'M[0-9][0-9][0-9][0-9][0-9][0-9]'
  AND date(substr(_batch_id,1,10)) IS NOT NULL), candidates AS (
  SELECT * FROM incoming
  {% if is_incremental() %}
  UNION ALL
  SELECT h.* FROM {{ this }} AS h
  JOIN (SELECT DISTINCT merchant_id,snapshot_day FROM incoming) AS k
    ON h.merchant_id=k.merchant_id AND h.snapshot_day=k.snapshot_day
  {% endif %}
), ranked AS (
  SELECT *,row_number() OVER (PARTITION BY merchant_id,snapshot_day ORDER BY loaded_ord DESC) AS rn
  FROM candidates
)
SELECT merchant_id,country,is_test,snapshot_day,loaded_ord FROM ranked WHERE rn=1;
 
-- task: currency_units
WITH units(currency, divisor, exponent) AS (
  VALUES
    ('AED', 100, 2),
    ('AFN', 100, 2),
    ('ALL', 100, 2),
    ('AMD', 100, 2),
    ('AOA', 100, 2),
    ('ARS', 100, 2),
    ('AUD', 100, 2),
    ('AWG', 100, 2),
    ('AZN', 100, 2),
    ('BAM', 100, 2),
    ('BBD', 100, 2),
    ('BDT', 100, 2),
    ('BHD', 1000, 3),
    ('BIF', 1, 0),
    ('BMD', 100, 2),
    ('BND', 100, 2),
    ('BOB', 100, 2),
    ('BOV', 100, 2),
    ('BRL', 100, 2),
    ('BSD', 100, 2),
    ('BTN', 100, 2),
    ('BWP', 100, 2),
    ('BYN', 100, 2),
    ('BZD', 100, 2),
    ('CAD', 100, 2),
    ('CDF', 100, 2),
    ('CHE', 100, 2),
    ('CHF', 100, 2),
    ('CHW', 100, 2),
    ('CLF', 10000, 4),
    ('CLP', 1, 0),
    ('CNY', 100, 2),
    ('COP', 100, 2),
    ('COU', 100, 2),
    ('CRC', 100, 2),
    ('CUP', 100, 2),
    ('CVE', 100, 2),
    ('CZK', 100, 2),
    ('DJF', 1, 0),
    ('DKK', 100, 2),
    ('DOP', 100, 2),
    ('DZD', 100, 2),
    ('EGP', 100, 2),
    ('ERN', 100, 2),
    ('ETB', 100, 2),
    ('EUR', 100, 2),
    ('FJD', 100, 2),
    ('FKP', 100, 2),
    ('GBP', 100, 2),
    ('GEL', 100, 2),
    ('GHS', 100, 2),
    ('GIP', 100, 2),
    ('GMD', 100, 2),
    ('GNF', 1, 0),
    ('GTQ', 100, 2),
    ('GYD', 100, 2),
    ('HKD', 100, 2),
    ('HNL', 100, 2),
    ('HTG', 100, 2),
    ('HUF', 100, 2),
    ('IDR', 100, 2),
    ('ILS', 100, 2),
    ('INR', 100, 2),
    ('IQD', 1000, 3),
    ('IRR', 100, 2),
    ('ISK', 1, 0),
    ('JMD', 100, 2),
    ('JOD', 1000, 3),
    ('JPY', 1, 0),
    ('KES', 100, 2),
    ('KGS', 100, 2),
    ('KHR', 100, 2),
    ('KMF', 1, 0),
    ('KPW', 100, 2),
    ('KRW', 1, 0),
    ('KWD', 1000, 3),
    ('KYD', 100, 2),
    ('KZT', 100, 2),
    ('LAK', 100, 2),
    ('LBP', 100, 2),
    ('LKR', 100, 2),
    ('LRD', 100, 2),
    ('LSL', 100, 2),
    ('LYD', 1000, 3),
    ('MAD', 100, 2),
    ('MDL', 100, 2),
    ('MGA', 100, 2),
    ('MKD', 100, 2),
    ('MMK', 100, 2),
    ('MNT', 100, 2),
    ('MOP', 100, 2),
    ('MRU', 100, 2),
    ('MUR', 100, 2),
    ('MVR', 100, 2),
    ('MWK', 100, 2),
    ('MXN', 100, 2),
    ('MXV', 100, 2),
    ('MYR', 100, 2),
    ('MZN', 100, 2),
    ('NAD', 100, 2),
    ('NGN', 100, 2),
    ('NIO', 100, 2),
    ('NOK', 100, 2),
    ('NPR', 100, 2),
    ('NZD', 100, 2),
    ('OMR', 1000, 3),
    ('PAB', 100, 2),
    ('PEN', 100, 2),
    ('PGK', 100, 2),
    ('PHP', 100, 2),
    ('PKR', 100, 2),
    ('PLN', 100, 2),
    ('PYG', 1, 0),
    ('QAR', 100, 2),
    ('RON', 100, 2),
    ('RSD', 100, 2),
    ('RUB', 100, 2),
    ('RWF', 1, 0),
    ('SAR', 100, 2),
    ('SBD', 100, 2),
    ('SCR', 100, 2),
    ('SDG', 100, 2),
    ('SEK', 100, 2),
    ('SGD', 100, 2),
    ('SHP', 100, 2),
    ('SLE', 100, 2),
    ('SOS', 100, 2),
    ('SRD', 100, 2),
    ('SSP', 100, 2),
    ('STN', 100, 2),
    ('SVC', 100, 2),
    ('SYP', 100, 2),
    ('SZL', 100, 2),
    ('THB', 100, 2),
    ('TJS', 100, 2),
    ('TMT', 100, 2),
    ('TND', 1000, 3),
    ('TOP', 100, 2),
    ('TRY', 100, 2),
    ('TTD', 100, 2),
    ('TWD', 100, 2),
    ('TZS', 100, 2),
    ('UAH', 100, 2),
    ('UGX', 1, 0),
    ('USD', 100, 2),
    ('USN', 100, 2),
    ('UYI', 1, 0),
    ('UYU', 100, 2),
    ('UYW', 10000, 4),
    ('UZS', 100, 2),
    ('VED', 100, 2),
    ('VES', 100, 2),
    ('VND', 1, 0),
    ('VUV', 1, 0),
    ('WST', 100, 2),
    ('XAD', 100, 2),
    ('XAF', 1, 0),
    ('XCD', 100, 2),
    ('XCG', 100, 2),
    ('XOF', 1, 0),
    ('XPF', 1, 0),
    ('YER', 100, 2),
    ('ZAR', 100, 2),
    ('ZMW', 100, 2),
    ('ZWG', 100, 2)
)
SELECT * FROM units;
 
-- task: fx_intervals
SELECT currency,rate_date,rate_value,rate_num,rate_den,
       lead(rate_date,1,'9999-12-31') OVER (PARTITION BY currency ORDER BY rate_date) AS next_date
FROM fx_rates_history;
 
-- task: merchant_intervals
SELECT merchant_id,country,is_test,snapshot_day,
       lead(snapshot_day,1,'9999-12-31') OVER (PARTITION BY merchant_id ORDER BY snapshot_day) AS next_date
FROM merchants_history;
 
-- task: payment_states
WITH resolved AS (
  SELECT payment_id,
         max(CASE WHEN merchant_id_ver IS NOT NULL THEN printf('%019d',merchant_id_ver) || char(31) || json_quote(merchant_id) END) AS merchant_id_packed,
         max(CASE WHEN amount_minor_ver IS NOT NULL THEN printf('%019d',amount_minor_ver) || char(31) || json_quote(amount_minor) END) AS amount_minor_packed,
         max(CASE WHEN currency_ver IS NOT NULL THEN printf('%019d',currency_ver) || char(31) || json_quote(currency) END) AS currency_packed,
         max(CASE WHEN created_at_ver IS NOT NULL THEN printf('%019d',created_at_ver) || char(31) || json_quote(created_at) END) AS created_at_packed,
         max(CASE WHEN captured_at_ver IS NOT NULL THEN printf('%019d',captured_at_ver) || char(31) || json_quote(captured_at) END) AS captured_at_packed,
         max(CASE WHEN status_ver IS NOT NULL THEN printf('%019d',status_ver) || char(31) || json_quote(status) END) AS status_packed,
         max(CASE WHEN order_ref_ver IS NOT NULL THEN printf('%019d',order_ref_ver) || char(31) || json_quote(order_ref) END) AS order_ref_packed,
         sum(coalesce(settled_minor,0)) AS settled_minor,
         sum(CASE WHEN effective_day BETWEEN '2026-09-18' AND '2026-10-12' THEN coalesce(settled_minor,0) ELSE 0 END) AS period_minor
  FROM payments_history GROUP BY payment_id
)
SELECT payment_id,CASE WHEN json_valid(substr(merchant_id_packed,instr(merchant_id_packed,char(31))+1)) THEN json_extract(substr(merchant_id_packed,instr(merchant_id_packed,char(31))+1),'$') END AS merchant_id,CASE WHEN json_valid(substr(amount_minor_packed,instr(amount_minor_packed,char(31))+1)) THEN json_extract(substr(amount_minor_packed,instr(amount_minor_packed,char(31))+1),'$') END AS amount_minor,CASE WHEN json_valid(substr(currency_packed,instr(currency_packed,char(31))+1)) THEN json_extract(substr(currency_packed,instr(currency_packed,char(31))+1),'$') END AS currency,CASE WHEN json_valid(substr(created_at_packed,instr(created_at_packed,char(31))+1)) THEN json_extract(substr(created_at_packed,instr(created_at_packed,char(31))+1),'$') END AS created_at,CASE WHEN json_valid(substr(captured_at_packed,instr(captured_at_packed,char(31))+1)) THEN json_extract(substr(captured_at_packed,instr(captured_at_packed,char(31))+1),'$') END AS captured_at,CASE WHEN json_valid(substr(status_packed,instr(status_packed,char(31))+1)) THEN json_extract(substr(status_packed,instr(status_packed,char(31))+1),'$') END AS status,CASE WHEN json_valid(substr(order_ref_packed,instr(order_ref_packed,char(31))+1)) THEN json_extract(substr(order_ref_packed,instr(order_ref_packed,char(31))+1),'$') END AS order_ref,settled_minor,period_minor FROM resolved;
 
-- task: fct_payments
WITH fct_states AS MATERIALIZED (
  -- Decode the compact history values once before joins and money arithmetic.
  -- Otherwise SQLite can inline and repeat the JSON expressions at each use.
  SELECT * FROM payment_states
), joined AS (
  SELECT p.*,m.country AS merchant_country,u.divisor,
         CASE WHEN p.currency='USD' THEN 1 ELSE f.rate_num END AS rate_num,
         CASE WHEN p.currency='USD' THEN 1 ELSE f.rate_den END AS rate_den
  FROM fct_states AS p
  LEFT JOIN currency_units AS u ON u.currency=p.currency
  LEFT JOIN fx_intervals AS f ON f.currency=p.currency
    AND date(p.created_at)>=f.rate_date AND date(p.created_at)<f.next_date
  LEFT JOIN merchant_intervals AS m ON m.merchant_id=p.merchant_id
    AND date(p.created_at)>=m.snapshot_day AND date(p.created_at)<m.next_date
  WHERE coalesce(m.is_test,0)=0
), fractions AS (
  SELECT *, amount_minor * rate_num * CASE WHEN divisor=1 THEN 100 WHEN divisor=10 THEN 10 ELSE 1 END AS amount_numerator,
         settled_minor * rate_num * CASE WHEN divisor=1 THEN 100 WHEN divisor=10 THEN 10 ELSE 1 END AS settled_numerator,
         period_minor * rate_num * CASE WHEN divisor=1 THEN 100 WHEN divisor=10 THEN 10 ELSE 1 END AS period_numerator,
         CASE WHEN divisor IS NOT NULL THEN rate_den * CASE WHEN divisor>=100 THEN divisor/100 ELSE 1 END END AS denominator
  FROM joined
), rounded AS (
  SELECT *, CASE WHEN amount_numerator IS NULL OR denominator IS NULL THEN NULL
      WHEN typeof(amount_numerator)='integer' AND amount_numerator>-9223372036854775808 AND typeof(denominator)='integer' AND denominator>0
        THEN (CASE WHEN amount_numerator<0 THEN -1 ELSE 1 END) *
             (abs(amount_numerator) / denominator + CASE WHEN abs(amount_numerator) % denominator >= (denominator+1)/2 THEN 1 ELSE 0 END)
      ELSE CAST(round(amount_numerator * 1.0 / denominator,0) AS INTEGER) END AS amount_cents,
         CASE WHEN settled_numerator IS NULL OR denominator IS NULL THEN NULL
      WHEN typeof(settled_numerator)='integer' AND settled_numerator>-9223372036854775808 AND typeof(denominator)='integer' AND denominator>0
        THEN (CASE WHEN settled_numerator<0 THEN -1 ELSE 1 END) *
             (abs(settled_numerator) / denominator + CASE WHEN abs(settled_numerator) % denominator >= (denominator+1)/2 THEN 1 ELSE 0 END)
      ELSE CAST(round(settled_numerator * 1.0 / denominator,0) AS INTEGER) END AS settled_cents,
         CASE WHEN period_numerator IS NULL OR denominator IS NULL THEN NULL
      WHEN typeof(period_numerator)='integer' AND period_numerator>-9223372036854775808 AND typeof(denominator)='integer' AND denominator>0
        THEN (CASE WHEN period_numerator<0 THEN -1 ELSE 1 END) *
             (abs(period_numerator) / denominator + CASE WHEN abs(period_numerator) % denominator >= (denominator+1)/2 THEN 1 ELSE 0 END)
      ELSE CAST(round(period_numerator * 1.0 / denominator,0) AS INTEGER) END AS period_cents
  FROM fractions
)
SELECT payment_id,status,
       CASE WHEN amount_cents IS NOT NULL THEN printf('%.2f',amount_cents/100.0) END AS amount_usd,
       CASE WHEN settled_cents IS NOT NULL THEN printf('%.2f',settled_cents/100.0) ELSE '0.00' END AS settled_usd,
       CASE WHEN period_cents IS NOT NULL THEN printf('%.2f',period_cents/100.0) ELSE '0.00' END AS settled_in_period_usd,
       captured_at,CAST(order_ref AS TEXT) AS order_ref,merchant_country
FROM rounded;
