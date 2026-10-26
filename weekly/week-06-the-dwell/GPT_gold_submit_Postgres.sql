-- Week 06 | PostgreSQL 16+ reference companion
-- Original: gold_submit.sql (SQLite). PostgreSQL adaptation, readable teaching version.
-- EACH SECTION IS ONE SELECT for one DAG task; split into task SQL files for execution.
-- NOT directly executable as a single .sql script.
-- Jinja {% if is_incremental() %} / {{ this }} requires an external DAG/dbt-style renderer.
-- Assumptions: raw input columns are TEXT or castable to TEXT; session TIME ZONE 'UTC'.
-- Requires PostgreSQL 16+ for IS JSON; no extensions.
-- STATIC REVIEW ONLY: not run on PostgreSQL or compared against sample.
-- NOTE: PostgreSQL array_agg over versions can require memory on large histories;
-- verify execution plans and replace with window ranking when scaling.
-- Amounts are integer ten-thousandths until rounded to cents for output.
-- dag.yml metadata for reference (separate file in real use):
-- schedule: nightly; start: 2026-09-25; end: 2026-10-24
-- unit_visit_history: incremental merge src_key; depends_on unit_visit
-- tariff_rate_history: incremental merge tariff_cd,eff_date; depends_on tariff_rate
-- line_operator_history: incremental merge line_scac,snap_day; depends_on line_operator
-- visits_latest: table; depends_on unit_visit_history
-- visit_days: table; depends_on unit_visit_history,visits_latest
-- tariff_day_rates: table; depends_on visit_days,tariff_rate_history
-- visit_charges: table; depends_on visit_days,tariff_day_rates
-- visit_lines: table; depends_on visits_latest,line_operator_history
-- storage_charges: table; depends_on visits_latest,visit_charges,visit_lines


-- ============================================================================
-- task: unit_visit_history
-- One SELECT: materialize as unit_visit_history using the orchestration DAG.
-- ============================================================================
WITH source_rows AS (
 SELECT coalesce(r.visit_gkey::text,'') || '|' || coalesce(r._batch_id::text,'') || '|' || coalesce(r._restated_day::text,'') || '|' || coalesce(r._loaded_at::text,'') || '|' || coalesce(r.last_upd_time::text,'') || '|' || coalesce(r.days_chg::text,'') || '|' || coalesce(r.visit_state::text,'') || '|' || coalesce(r.gate_out_time::text,'') || '|' || coalesce(r.unit_nbr::text,'') AS src_key,
  CASE WHEN upper(btrim(r.visit_gkey::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.visit_gkey::text) END AS visit_raw,
  CASE WHEN upper(btrim(r.unit_nbr::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.unit_nbr::text) END AS unit_raw,
  CASE WHEN upper(btrim(r.line_scac::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.line_scac::text) END AS line_raw,
  CASE WHEN upper(btrim(r.visit_state::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.visit_state::text) END AS state_raw,
  CASE WHEN upper(btrim(r.tariff_cd::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.tariff_cd::text) END AS tariff_raw,
  CASE WHEN upper(btrim(r.days_chg::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.days_chg::text) END AS days_raw,
  CASE WHEN upper(btrim(r.dsch_time::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.dsch_time::text) END AS discharge_raw,
  CASE WHEN upper(btrim(r.gate_out_time::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.gate_out_time::text) END AS gate_raw,
  CASE WHEN upper(btrim(r.last_upd_time::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r.last_upd_time::text) END AS update_raw,
  CASE WHEN upper(btrim(r._batch_id::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r._batch_id::text) END AS batch_raw,
  CASE WHEN upper(btrim(r._restated_day::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r._restated_day::text) END AS restated_raw,
  CASE WHEN upper(btrim(r._loaded_at::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(r._loaded_at::text) END AS loaded_raw,
  r.remarks::text AS remarks
 FROM unit_visit r
 {% if is_incremental() %}
 LEFT JOIN {{ this }} x ON x.src_key = coalesce(r.visit_gkey::text,'') || '|' || coalesce(r._batch_id::text,'') || '|' || coalesce(r._restated_day::text,'') || '|' || coalesce(r._loaded_at::text,'') || '|' || coalesce(r.last_upd_time::text,'') || '|' || coalesce(r.days_chg::text,'') || '|' || coalesce(r.visit_state::text,'') || '|' || coalesce(r.gate_out_time::text,'') || '|' || coalesce(r.unit_nbr::text,'')
 WHERE x.src_key IS NULL
 {% endif %}
),
normalized AS (
 SELECT *,
  CASE WHEN visit_raw ~ '^[0-9]+(\.0)?$'
    THEN (regexp_replace(visit_raw,'\.0$','')::numeric)::text END AS visit_gkey,
  upper(regexp_replace(unit_raw,'[ ._-]','','g')) AS unit_nbr,
  upper(line_raw) AS line_scac,
  lower(replace(replace(state_raw,' ','_'),'-','_')) AS state_norm,
  upper(tariff_raw) AS tariff_cd,
  CASE WHEN days_raw ~ '^-?[0-9]+(\.[0-9]+)?$' THEN days_raw::numeric END AS days,
  to_char((CASE
 WHEN discharge_raw IS NULL THEN NULL
 WHEN discharge_raw ~ '^[0-9]{13}$' THEN to_timestamp((discharge_raw)::numeric / 1000)
 WHEN discharge_raw ~ '^[0-9]{10}$' THEN to_timestamp((discharge_raw)::numeric)
 WHEN discharge_raw ~ '[+-][0-9]{4}$' THEN (left(discharge_raw,length(discharge_raw)-2)||':'||right(discharge_raw,2))::timestamptz
 WHEN discharge_raw ~ '[+-][0-9]{2}$' THEN (discharge_raw||':00')::timestamptz
 WHEN discharge_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN discharge_raw::timestamptz
 WHEN upper(discharge_raw) LIKE '% UTC' THEN replace(upper(discharge_raw),' UTC','+00:00')::timestamptz
 ELSE (discharge_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS dsch_utc,
  to_char((CASE
 WHEN gate_raw IS NULL THEN NULL
 WHEN gate_raw ~ '^[0-9]{13}$' THEN to_timestamp((gate_raw)::numeric / 1000)
 WHEN gate_raw ~ '^[0-9]{10}$' THEN to_timestamp((gate_raw)::numeric)
 WHEN gate_raw ~ '[+-][0-9]{4}$' THEN (left(gate_raw,length(gate_raw)-2)||':'||right(gate_raw,2))::timestamptz
 WHEN gate_raw ~ '[+-][0-9]{2}$' THEN (gate_raw||':00')::timestamptz
 WHEN gate_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN gate_raw::timestamptz
 WHEN upper(gate_raw) LIKE '% UTC' THEN replace(upper(gate_raw),' UTC','+00:00')::timestamptz
 ELSE (gate_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS gate_utc,
  to_char((CASE
 WHEN update_raw IS NULL THEN NULL
 WHEN update_raw ~ '^[0-9]{13}$' THEN to_timestamp((update_raw)::numeric / 1000)
 WHEN update_raw ~ '^[0-9]{10}$' THEN to_timestamp((update_raw)::numeric)
 WHEN update_raw ~ '[+-][0-9]{4}$' THEN (left(update_raw,length(update_raw)-2)||':'||right(update_raw,2))::timestamptz
 WHEN update_raw ~ '[+-][0-9]{2}$' THEN (update_raw||':00')::timestamptz
 WHEN update_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN update_raw::timestamptz
 WHEN upper(update_raw) LIKE '% UTC' THEN replace(upper(update_raw),' UTC','+00:00')::timestamptz
 ELSE (update_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS upd_utc,
  to_char((CASE
 WHEN loaded_raw IS NULL THEN NULL
 WHEN loaded_raw ~ '^[0-9]{13}$' THEN to_timestamp((loaded_raw)::numeric / 1000)
 WHEN loaded_raw ~ '^[0-9]{10}$' THEN to_timestamp((loaded_raw)::numeric)
 WHEN loaded_raw ~ '[+-][0-9]{4}$' THEN (left(loaded_raw,length(loaded_raw)-2)||':'||right(loaded_raw,2))::timestamptz
 WHEN loaded_raw ~ '[+-][0-9]{2}$' THEN (loaded_raw||':00')::timestamptz
 WHEN loaded_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN loaded_raw::timestamptz
 WHEN upper(loaded_raw) LIKE '% UTC' THEN replace(upper(loaded_raw),' UTC','+00:00')::timestamptz
 ELSE (loaded_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS loaded_utc,
  CASE WHEN batch_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    THEN batch_raw::date END AS batch_day,
  CASE WHEN restated_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'
    THEN restated_raw::date END AS rest_day
 FROM source_rows
),
parsed_booking AS (
 SELECT *,
  CASE
   WHEN remarks IS JSON THEN coalesce(remarks::jsonb->>'booking_ref',remarks::jsonb->>'bookingRef')
   ELSE substring(remarks FROM '"(?:booking_ref|bookingRef)"[[:space:]]*:[[:space:]]*"([^"]+)"')
  END AS booking_value
 FROM normalized
),
resolved AS (
 SELECT src_key, visit_gkey,
   coalesce(rest_day,batch_day,(loaded_utc::timestamptz - interval '1 day')::date) AS eff_day,
   batch_day,
   CASE WHEN unit_nbr ~ '^[A-Z]{4}[0-9]{7}$' THEN unit_nbr END AS unit_nbr,
   line_scac,state_norm,tariff_cd,days,dsch_utc,gate_utc,upd_utc,loaded_utc,
   CASE WHEN upper(btrim(booking_value)) IN ('','NULL',E'\\N','NONE','NAN','N/A','NA','-','--','NIL','UNDEFINED','?','UNKNOWN')
    THEN NULL ELSE btrim(booking_value) END AS booking_ref,
   CASE WHEN rest_day IS NOT NULL THEN 1 ELSE 0 END AS restated,
   row_number() OVER (PARTITION BY src_key ORDER BY loaded_utc DESC NULLS LAST) AS row_priority
 FROM parsed_booking WHERE visit_gkey IS NOT NULL
)
SELECT src_key,visit_gkey,eff_day,batch_day,unit_nbr,line_scac,state_norm,tariff_cd,days,
 dsch_utc,gate_utc,upd_utc,loaded_utc,booking_ref,restated
FROM resolved WHERE row_priority=1 AND eff_day IS NOT NULL

-- ============================================================================
-- task: tariff_rate_history
-- One SELECT: materialize as tariff_rate_history using the orchestration DAG.
-- ============================================================================
WITH incoming AS (
 SELECT upper(CASE WHEN upper(btrim(tariff_cd::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(tariff_cd::text) END) AS tariff_cd,
  CASE WHEN upper(btrim(eff_date::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(eff_date::text) END AS effective_raw,
  CASE WHEN upper(btrim(rate_usd::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(rate_usd::text) END AS rate_raw,
  CASE WHEN upper(btrim(_loaded_at::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(_loaded_at::text) END AS loaded_raw
 FROM tariff_rate
),
typed AS (
 SELECT tariff_cd,
  CASE WHEN effective_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN effective_raw::date END AS eff_date,
  CASE WHEN rate_raw LIKE '%,%' AND rate_raw NOT LIKE '%.%'
    THEN replace(replace(rate_raw,',','.'),'$','')
    ELSE replace(replace(rate_raw,',',''),'$','') END AS rate_text,
  to_char((CASE
 WHEN loaded_raw IS NULL THEN NULL
 WHEN loaded_raw ~ '^[0-9]{13}$' THEN to_timestamp((loaded_raw)::numeric / 1000)
 WHEN loaded_raw ~ '^[0-9]{10}$' THEN to_timestamp((loaded_raw)::numeric)
 WHEN loaded_raw ~ '[+-][0-9]{4}$' THEN (left(loaded_raw,length(loaded_raw)-2)||':'||right(loaded_raw,2))::timestamptz
 WHEN loaded_raw ~ '[+-][0-9]{2}$' THEN (loaded_raw||':00')::timestamptz
 WHEN loaded_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN loaded_raw::timestamptz
 WHEN upper(loaded_raw) LIKE '% UTC' THEN replace(upper(loaded_raw),' UTC','+00:00')::timestamptz
 ELSE (loaded_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS loaded_utc
 FROM incoming
),
ranked AS (
 SELECT tariff_cd,eff_date,rate_text::numeric AS rate_usd,loaded_utc,
  row_number() OVER (PARTITION BY tariff_cd,eff_date ORDER BY loaded_utc DESC NULLS LAST) AS rn
 FROM typed
 WHERE tariff_cd IS NOT NULL AND eff_date IS NOT NULL AND rate_text ~ '^[0-9]+(\.[0-9]+)?$'
)
SELECT d.tariff_cd,d.eff_date,d.rate_usd,d.loaded_utc FROM ranked d
{% if is_incremental() %}
LEFT JOIN {{ this }} o ON o.tariff_cd=d.tariff_cd AND o.eff_date=d.eff_date
{% endif %}
WHERE d.rn=1
{% if is_incremental() %}
AND (o.tariff_cd IS NULL OR d.loaded_utc >= o.loaded_utc OR o.loaded_utc IS NULL)
{% endif %}

-- ============================================================================
-- task: line_operator_history
-- One SELECT: materialize as line_operator_history using the orchestration DAG.
-- ============================================================================
WITH incoming AS (
 SELECT upper(CASE WHEN upper(btrim(line_scac::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(line_scac::text) END) AS line_scac,
  CASE WHEN upper(btrim(_batch_id::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(_batch_id::text) END AS batch_raw,
  CASE WHEN upper(btrim(bill_to::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(bill_to::text) END AS bill_raw,
  upper(CASE WHEN upper(btrim(test_flag::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(test_flag::text) END) AS test_raw,
  CASE WHEN upper(btrim(_loaded_at::text)) IN ('','NULL',E'\\N','NONE','NAN','N/A','-') THEN NULL ELSE btrim(_loaded_at::text) END AS loaded_raw
 FROM line_operator
),
normalized AS (
 SELECT line_scac,
  CASE WHEN batch_raw ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN batch_raw::date END AS snap_day,
  CASE WHEN upper(bill_raw) IN ('','NULL',E'\\N','NONE','NAN','N/A','NA','-','--','NIL','UNDEFINED','?','UNKNOWN')
   THEN NULL ELSE upper(bill_raw) END AS bill_to,
  CASE WHEN test_raw IN ('Y','YES','TRUE','1','T') THEN 1
       WHEN test_raw IN ('N','NO','FALSE','0','F') THEN 0 END AS is_test,
  to_char((CASE
 WHEN loaded_raw IS NULL THEN NULL
 WHEN loaded_raw ~ '^[0-9]{13}$' THEN to_timestamp((loaded_raw)::numeric / 1000)
 WHEN loaded_raw ~ '^[0-9]{10}$' THEN to_timestamp((loaded_raw)::numeric)
 WHEN loaded_raw ~ '[+-][0-9]{4}$' THEN (left(loaded_raw,length(loaded_raw)-2)||':'||right(loaded_raw,2))::timestamptz
 WHEN loaded_raw ~ '[+-][0-9]{2}$' THEN (loaded_raw||':00')::timestamptz
 WHEN loaded_raw ~ '(Z|z|[+-][0-9]{2}:[0-9]{2})$' THEN loaded_raw::timestamptz
 WHEN upper(loaded_raw) LIKE '% UTC' THEN replace(upper(loaded_raw),' UTC','+00:00')::timestamptz
 ELSE (loaded_raw::timestamp AT TIME ZONE 'Etc/GMT-8')
 END) AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"') AS loaded_utc
 FROM incoming
),
ranked AS (
 SELECT *,row_number() OVER (PARTITION BY line_scac,snap_day ORDER BY loaded_utc DESC NULLS LAST) AS rn
 FROM normalized WHERE line_scac IS NOT NULL AND snap_day IS NOT NULL
)
{% if is_incremental() %}
, current_line AS (
 SELECT DISTINCT ON (line_scac) line_scac,bill_to,is_test FROM {{ this }}
 ORDER BY line_scac,snap_day DESC
)
{% endif %}
SELECT d.line_scac,d.snap_day,d.bill_to,d.is_test
FROM ranked d
{% if is_incremental() %}
LEFT JOIN current_line c ON c.line_scac=d.line_scac
{% endif %}
WHERE d.rn=1
{% if is_incremental() %}
AND (c.line_scac IS NULL OR c.bill_to IS DISTINCT FROM d.bill_to OR c.is_test IS DISTINCT FROM d.is_test)
{% endif %}

-- ============================================================================
-- task: visits_latest
-- One SELECT: materialize as visits_latest using the orchestration DAG.
-- ============================================================================
WITH latest AS (
 SELECT visit_gkey,min(eff_day) AS first_day,
  (array_agg(unit_nbr ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE unit_nbr IS NOT NULL))[1] AS unit_nbr,
  (array_agg(line_scac ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE line_scac IS NOT NULL))[1] AS line_scac,
  (array_agg(state_norm ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE state_norm IS NOT NULL))[1] AS state_raw,
  (array_agg(tariff_cd ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE tariff_cd IS NOT NULL))[1] AS tariff_cd,
  (array_agg(dsch_utc ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE dsch_utc IS NOT NULL))[1] AS dsch_utc,
  (array_agg(gate_utc ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE gate_utc IS NOT NULL))[1] AS gate_out_time,
  (array_agg(booking_ref ORDER BY upd_utc DESC NULLS LAST,batch_day DESC NULLS LAST,loaded_utc DESC NULLS LAST) FILTER (WHERE booking_ref IS NOT NULL))[1] AS booking_ref
 FROM unit_visit_history GROUP BY visit_gkey
)
SELECT visit_gkey,first_day,unit_nbr,line_scac,
 CASE
  WHEN state_raw IN ('discharged','discharge','dischgd','dischd','disch','unloaded') THEN 'discharged'
  WHEN state_raw IN ('held','hold','on_hold','holding') THEN 'held'
  WHEN state_raw IN ('gated_out','gate_out','gatedout','gateout','gated','exited','exit','departed','out') THEN 'gated_out'
  WHEN state_raw IN ('transshipped','transhipped','transshipment','transship','tranship','trans','ts') THEN 'transshipped'
 END AS visit_state,
 tariff_cd,dsch_utc,gate_out_time,booking_ref
FROM latest

-- ============================================================================
-- task: visit_days
-- One SELECT: materialize as visit_days using the orchestration DAG.
-- ============================================================================
WITH daily_resolved AS (
 SELECT visit_gkey,eff_day,
  (array_agg(days ORDER BY restated DESC,upd_utc DESC NULLS LAST,loaded_utc DESC NULLS LAST)
    FILTER (WHERE days IS NOT NULL))[1] AS days,
  (array_agg(tariff_cd ORDER BY restated DESC,upd_utc DESC NULLS LAST,loaded_utc DESC NULLS LAST)
    FILTER (WHERE tariff_cd IS NOT NULL))[1] AS day_tariff
 FROM unit_visit_history GROUP BY visit_gkey,eff_day
)
SELECT d.visit_gkey,d.eff_day,d.days,coalesce(d.day_tariff,v.tariff_cd) AS tariff_cd
FROM daily_resolved d LEFT JOIN visits_latest v USING(visit_gkey)
WHERE d.days IS NOT NULL

-- ============================================================================
-- task: tariff_day_rates
-- One SELECT: materialize as tariff_day_rates using the orchestration DAG.
-- ============================================================================
WITH needed_days AS (
 SELECT DISTINCT tariff_cd,eff_day AS day FROM visit_days WHERE tariff_cd IS NOT NULL
)
SELECT p.tariff_cd,p.day,
 (SELECT round(t.rate_usd*10000)::bigint FROM tariff_rate_history t
  WHERE t.tariff_cd=p.tariff_cd AND t.eff_date<=p.day
  ORDER BY t.eff_date DESC LIMIT 1) AS rate_i
FROM needed_days p

-- ============================================================================
-- task: visit_charges
-- One SELECT: materialize as visit_charges using the orchestration DAG.
-- ============================================================================
SELECT d.visit_gkey,
 sum(round(d.days*r.rate_i)::bigint) AS tot_i,
 sum(CASE WHEN d.eff_day<=DATE '2026-10-19' THEN round(d.days*r.rate_i)::bigint ELSE 0 END) AS per_i
FROM visit_days d
LEFT JOIN tariff_day_rates r ON r.tariff_cd=d.tariff_cd AND r.day=d.eff_day
GROUP BY d.visit_gkey

-- ============================================================================
-- task: visit_lines
-- One SELECT: materialize as visit_lines using the orchestration DAG.
-- ============================================================================
WITH visits AS (
 SELECT visit_gkey,line_scac,
 coalesce((dsch_utc::timestamptz+interval '2 hours')::date,first_day) AS discharge_day
 FROM visits_latest WHERE line_scac IS NOT NULL
)
SELECT v.visit_gkey,s.bill_to,s.is_test
FROM visits v
LEFT JOIN LATERAL (
 SELECT l.bill_to,l.is_test
 FROM line_operator_history l WHERE l.line_scac=v.line_scac
 ORDER BY (CASE WHEN l.snap_day<=v.discharge_day THEN 0 ELSE 1 END),
  (CASE WHEN l.snap_day<=v.discharge_day THEN l.snap_day END) DESC NULLS LAST,
  (CASE WHEN l.snap_day>v.discharge_day THEN l.snap_day END) ASC NULLS LAST
 LIMIT 1
) s ON TRUE

-- ============================================================================
-- task: storage_charges
-- One SELECT: materialize as storage_charges using the orchestration DAG.
-- ============================================================================
SELECT v.visit_gkey,v.unit_nbr,v.visit_state,v.gate_out_time,v.booking_ref,
 to_char(round(coalesce(c.tot_i,0)::numeric/100)/100,'FM999999999999999990.00') AS storage_usd,
 to_char(round(coalesce(c.per_i,0)::numeric/100)/100,'FM999999999999999990.00') AS storage_in_period_usd,
 l.bill_to
FROM visits_latest v
LEFT JOIN visit_charges c USING(visit_gkey)
LEFT JOIN visit_lines l USING(visit_gkey)
WHERE coalesce(l.is_test,0)=0
