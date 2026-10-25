/* dag.yml
dag: the_dwell
schedule: nightly
start_date: 2026-09-25
end_date: 2026-10-24
catchup: true
tasks:
  unit_visit_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [src_key]
    depends_on: [unit_visit]
  tariff_rate_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [tariff_cd, eff_date]
    depends_on: [tariff_rate]
  line_operator_history:
    materialized: incremental
    incremental_strategy: merge
    unique_key: [line_scac, snap_day]
    depends_on: [line_operator]
  visits_latest:
    materialized: table
    depends_on: [unit_visit_history]
    tests:
      - unique: visit_gkey
        severity: warn
  visit_days:
    materialized: table
    depends_on: [unit_visit_history, visits_latest]
  tariff_day_rates:
    materialized: table
    depends_on: [visit_days, tariff_rate_history]
  visit_charges:
    materialized: table
    depends_on: [visit_days, tariff_day_rates]
  visit_lines:
    materialized: table
    depends_on: [visits_latest, line_operator_history]
  storage_charges:
    materialized: table
    depends_on: [visits_latest, visit_charges, visit_lines]
    tests:
      - unique: visit_gkey
        severity: warn
      - not_null: visit_gkey
        severity: warn
*/
 
-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after
 
-- task: unit_visit_history
-- Every distinct source row of the change log, cleaned, kept across runs because the landing
-- forgets after 7 nights. A row already held is skipped before any cleaning. Rows are never
-- collapsed here: each system fills only the columns it owns, so the day level and visit level
-- views below pick the newest non-null value of each column.
WITH s AS (
  SELECT CASE WHEN upper(trim(r.visit_gkey)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.visit_gkey) END AS gk, CASE WHEN upper(trim(r.unit_nbr)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.unit_nbr) END AS unit_raw, CASE WHEN upper(trim(r.line_scac)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.line_scac) END AS scac,
         CASE WHEN upper(trim(r.visit_state)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.visit_state) END AS st, CASE WHEN upper(trim(r.tariff_cd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.tariff_cd) END AS tcd, CASE WHEN upper(trim(r.days_chg)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.days_chg) END AS days_t,
         CASE WHEN upper(trim(r.dsch_time)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.dsch_time) END AS d_at, CASE WHEN upper(trim(r.gate_out_time)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.gate_out_time) END AS g_at, CASE WHEN upper(trim(r.last_upd_time)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r.last_upd_time) END AS u_at,
         CASE WHEN upper(trim(r._batch_id)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r._batch_id) END AS b_id, CASE WHEN upper(trim(r._restated_day)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r._restated_day) END AS rest, CASE WHEN upper(trim(r._loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(r._loaded_at) END AS l_at,
         r.remarks,
         COALESCE(r.visit_gkey, '') || '|' || COALESCE(r._batch_id, '') || '|' || COALESCE(r._restated_day, '') || '|' || COALESCE(r._loaded_at, '') || '|' || COALESCE(r.last_upd_time, '') || '|' || COALESCE(r.days_chg, '') || '|' || COALESCE(r.visit_state, '') || '|' || COALESCE(r.gate_out_time, '') || '|' || COALESCE(r.unit_nbr, '') AS src_key
  FROM unit_visit AS r
{% if is_incremental() %}
  LEFT JOIN {{ this }} AS x ON x.src_key = COALESCE(r.visit_gkey, '') || '|' || COALESCE(r._batch_id, '') || '|' || COALESCE(r._restated_day, '') || '|' || COALESCE(r._loaded_at, '') || '|' || COALESCE(r.last_upd_time, '') || '|' || COALESCE(r.days_chg, '') || '|' || COALESCE(r.visit_state, '') || '|' || COALESCE(r.gate_out_time, '') || '|' || COALESCE(r.unit_nbr, '')
  WHERE x.src_key IS NULL
{% endif %}
),
t AS (
  SELECT src_key,
         CASE WHEN gk IS NULL THEN NULL
              WHEN gk NOT GLOB '*[^0-9]*' THEN gk
              WHEN gk GLOB '*[0-9].0' AND substr(gk, 1, length(gk) - 2) NOT GLOB '*[^0-9]*' THEN substr(gk, 1, length(gk) - 2) END AS visit_gkey,
         upper(replace(replace(replace(replace(unit_raw, ' ', ''), '-', ''), '_', ''), '.', '')) AS unit_c,
         upper(scac) AS line_scac,
         lower(replace(replace(st, ' ', '_'), '-', '_')) AS state_norm,
         upper(tcd) AS tariff_cd,
         CASE WHEN days_t IS NOT NULL AND days_t GLOB '*[0-9]*' AND ltrim(days_t, '-') NOT GLOB '*[^0-9.]*'
                   AND length(days_t) - length(ltrim(days_t, '-')) <= 1
                   AND length(days_t) - length(replace(days_t, '.', '')) <= 1
              THEN CAST(days_t AS REAL) END AS days,
         CASE WHEN d_at IS NULL THEN NULL
         WHEN d_at NOT GLOB '*[^0-9]*' AND length(d_at) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(d_at AS INTEGER) / 1000, 'unixepoch')
         WHEN d_at NOT GLOB '*[^0-9]*' AND length(d_at) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(d_at AS INTEGER), 'unixepoch')
         WHEN d_at LIKE '%:%' AND d_at GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', d_at || ':00')
         WHEN d_at LIKE '%:%' AND d_at GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(d_at, 1, length(d_at) - 2) || ':' || substr(d_at, -2))
         WHEN d_at LIKE '%:%' AND d_at GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', d_at || ':00')
         WHEN d_at LIKE '%:%' AND d_at GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', d_at)
         WHEN d_at LIKE '%:%' AND (d_at GLOB '*Z' OR d_at GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', d_at)
         WHEN d_at LIKE '%:%' AND d_at LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(d_at, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', d_at || '+08:00') END AS dsch_utc,
         CASE WHEN g_at IS NULL THEN NULL
         WHEN g_at NOT GLOB '*[^0-9]*' AND length(g_at) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(g_at AS INTEGER) / 1000, 'unixepoch')
         WHEN g_at NOT GLOB '*[^0-9]*' AND length(g_at) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(g_at AS INTEGER), 'unixepoch')
         WHEN g_at LIKE '%:%' AND g_at GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', g_at || ':00')
         WHEN g_at LIKE '%:%' AND g_at GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(g_at, 1, length(g_at) - 2) || ':' || substr(g_at, -2))
         WHEN g_at LIKE '%:%' AND g_at GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', g_at || ':00')
         WHEN g_at LIKE '%:%' AND g_at GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', g_at)
         WHEN g_at LIKE '%:%' AND (g_at GLOB '*Z' OR g_at GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', g_at)
         WHEN g_at LIKE '%:%' AND g_at LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(g_at, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', g_at || '+08:00') END AS gate_utc,
         CASE WHEN u_at IS NULL THEN NULL
         WHEN u_at NOT GLOB '*[^0-9]*' AND length(u_at) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(u_at AS INTEGER) / 1000, 'unixepoch')
         WHEN u_at NOT GLOB '*[^0-9]*' AND length(u_at) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(u_at AS INTEGER), 'unixepoch')
         WHEN u_at LIKE '%:%' AND u_at GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', u_at || ':00')
         WHEN u_at LIKE '%:%' AND u_at GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(u_at, 1, length(u_at) - 2) || ':' || substr(u_at, -2))
         WHEN u_at LIKE '%:%' AND u_at GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', u_at || ':00')
         WHEN u_at LIKE '%:%' AND u_at GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', u_at)
         WHEN u_at LIKE '%:%' AND (u_at GLOB '*Z' OR u_at GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', u_at)
         WHEN u_at LIKE '%:%' AND u_at LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(u_at, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', u_at || '+08:00') END AS upd_utc,
         CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at NOT GLOB '*[^0-9]*' AND length(l_at) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(l_at AS INTEGER) / 1000, 'unixepoch')
         WHEN l_at NOT GLOB '*[^0-9]*' AND length(l_at) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(l_at AS INTEGER), 'unixepoch')
         WHEN l_at LIKE '%:%' AND l_at GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', l_at || ':00')
         WHEN l_at LIKE '%:%' AND l_at GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(l_at, 1, length(l_at) - 2) || ':' || substr(l_at, -2))
         WHEN l_at LIKE '%:%' AND l_at GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', l_at || ':00')
         WHEN l_at LIKE '%:%' AND l_at GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', l_at)
         WHEN l_at LIKE '%:%' AND (l_at GLOB '*Z' OR l_at GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', l_at)
         WHEN l_at LIKE '%:%' AND l_at LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(l_at, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', l_at) END AS loaded_utc,
         date(b_id) AS batch_day,
         date(rest) AS rest_day,
         remarks
  FROM s
),
k AS (
  SELECT *,
    CASE WHEN instr(remarks, '"booking_ref"') > 0 THEN instr(remarks, '"booking_ref"') + 13
         WHEN instr(remarks, '"bookingRef"') > 0 THEN instr(remarks, '"bookingRef"') + 12 END AS kpos
  FROM t
  WHERE visit_gkey IS NOT NULL
),
q AS (
  SELECT *, CASE WHEN kpos IS NOT NULL AND substr(ltrim(substr(remarks, kpos)), 1, 1) = ':'
                 THEN ltrim(substr(ltrim(substr(remarks, kpos)), 2)) END AS qv
  FROM k
),
b AS (
  SELECT *, CASE WHEN substr(qv, 1, 1) = '"' THEN substr(qv, 2) END AS body FROM q
),
e AS (
  SELECT src_key, visit_gkey,
         CASE WHEN unit_c GLOB '[A-Z][A-Z][A-Z][A-Z][0-9][0-9][0-9][0-9][0-9][0-9][0-9]' THEN unit_c END AS unit_nbr,
         line_scac, state_norm, tariff_cd, days, dsch_utc, gate_utc, upd_utc, loaded_utc, batch_day,
         COALESCE(rest_day, batch_day, date(loaded_utc, '-1 day')) AS eff_day,
         CASE WHEN rest_day IS NOT NULL THEN 1 ELSE 0 END AS restated,
         CASE WHEN json_valid(remarks) THEN COALESCE(CAST(json_extract(remarks, '$.booking_ref') AS TEXT),
                                                    CAST(json_extract(remarks, '$.bookingRef') AS TEXT))
              WHEN instr(body, '"') > 0 THEN substr(body, 1, instr(body, '"') - 1) END AS ref_raw
  FROM b
),
d AS (
  SELECT e.*,
         CASE WHEN upper(trim(ref_raw)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', 'NA', '-', '--', 'NIL', 'UNDEFINED', '?', 'UNKNOWN') THEN NULL ELSE trim(ref_raw) END AS booking_ref,
         row_number() OVER (PARTITION BY src_key ORDER BY loaded_utc DESC) AS rn
  FROM e
)
SELECT src_key, visit_gkey, eff_day, batch_day, unit_nbr, line_scac, state_norm, tariff_cd, days,
       dsch_utc, gate_utc, upd_utc, loaded_utc, booking_ref, restated
FROM d
WHERE rn = 1 AND eff_day IS NOT NULL
 
-- task: tariff_rate_history
-- One rate per tariff per effective day, kept across runs because the landing keeps 2 nights and
-- later nights carry only the changes. A rate sent again for the same day replaces the earlier one.
WITH n AS (
  SELECT upper(CASE WHEN upper(trim(tariff_cd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(tariff_cd) END) AS tariff_cd, date(CASE WHEN upper(trim(eff_date)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(eff_date) END) AS eff_date,
         CASE WHEN CASE WHEN upper(trim(rate_usd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(rate_usd) END IS NULL THEN NULL
         WHEN CASE WHEN upper(trim(rate_usd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(rate_usd) END LIKE '%,%' AND CASE WHEN upper(trim(rate_usd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(rate_usd) END NOT LIKE '%.%' THEN replace(replace(CASE WHEN upper(trim(rate_usd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(rate_usd) END, ',', '.'), '$', '')
         ELSE replace(replace(CASE WHEN upper(trim(rate_usd)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(rate_usd) END, ',', ''), '$', '') END AS rate_t, CASE WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END IS NULL THEN NULL
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END NOT GLOB '*[^0-9]*' AND length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END AS INTEGER) / 1000, 'unixepoch')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END NOT GLOB '*[^0-9]*' AND length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END AS INTEGER), 'unixepoch')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END || ':00')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, 1, length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) - 2) || ':' || substr(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, -2))
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END || ':00')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END)
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND (CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*Z' OR CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END)
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) END AS loaded_utc
  FROM tariff_rate
),
c AS (
  SELECT tariff_cd, eff_date, CAST(rate_t AS REAL) AS rate_usd, loaded_utc
  FROM n
  WHERE rate_t NOT GLOB '*[^0-9.]*' AND rate_t GLOB '[0-9]*' AND tariff_cd IS NOT NULL AND eff_date IS NOT NULL
),
d AS (
  SELECT c.*, row_number() OVER (PARTITION BY tariff_cd, eff_date ORDER BY loaded_utc DESC) AS rn FROM c
)
SELECT d.tariff_cd, d.eff_date, d.rate_usd, d.loaded_utc
FROM d
{% if is_incremental() %}
LEFT JOIN {{ this }} AS o ON o.tariff_cd = d.tariff_cd AND o.eff_date = d.eff_date
{% endif %}
WHERE d.rn = 1
{% if is_incremental() %}
  AND (o.tariff_cd IS NULL OR COALESCE(d.loaded_utc, '') >= COALESCE(o.loaded_utc, ''))
{% endif %}
 
-- task: line_operator_history
-- A shipping line row is stored when its bill-to party or test flag differs from the latest one
-- held. The landing keeps only the latest copy, so this is the only record of earlier states.
WITH m AS (
  SELECT upper(CASE WHEN upper(trim(line_scac)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(line_scac) END) AS line_scac, date(CASE WHEN upper(trim(_batch_id)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_batch_id) END) AS snap_day,
         CASE WHEN upper(CASE WHEN upper(trim(bill_to)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(bill_to) END) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', 'NA', '-', '--', 'NIL', 'UNDEFINED', '?', 'UNKNOWN') THEN NULL ELSE upper(CASE WHEN upper(trim(bill_to)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(bill_to) END) END AS bill_to,
         CASE WHEN upper(CASE WHEN upper(trim(test_flag)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(test_flag) END) IN ('Y', 'YES', 'TRUE', '1', 'T') THEN 1
              WHEN upper(CASE WHEN upper(trim(test_flag)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(test_flag) END) IN ('N', 'NO', 'FALSE', '0', 'F') THEN 0 END AS is_test,
         CASE WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END IS NULL THEN NULL
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END NOT GLOB '*[^0-9]*' AND length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) = 13 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END AS INTEGER) / 1000, 'unixepoch')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END NOT GLOB '*[^0-9]*' AND length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) = 10 THEN strftime('%Y-%m-%dT%H:%M:%SZ', CAST(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END AS INTEGER), 'unixepoch')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*:[0-9][0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END || ':00')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', substr(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, 1, length(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) - 2) || ':' || substr(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, -2))
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END || ':00')
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*[0-9][+-][0-9][0-9]:[0-9][0-9]' THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END)
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND (CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*Z' OR CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END GLOB '*z') THEN strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END)
         WHEN CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '%:%' AND CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END LIKE '% UTC' THEN strftime('%Y-%m-%dT%H:%M:%SZ', replace(CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END, ' UTC', ''))
         ELSE strftime('%Y-%m-%dT%H:%M:%SZ', CASE WHEN upper(trim(_loaded_at)) IN ('', 'NULL', char(92) || 'N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE trim(_loaded_at) END) END AS loaded_utc
  FROM line_operator
),
d AS (
  SELECT line_scac, snap_day, bill_to, is_test,
         row_number() OVER (PARTITION BY line_scac, snap_day ORDER BY loaded_utc DESC) AS rn
  FROM m
  WHERE line_scac IS NOT NULL AND snap_day IS NOT NULL
){% if is_incremental() %},
cur AS (
  SELECT line_scac, bill_to, is_test FROM (
    SELECT line_scac, bill_to, is_test,
           row_number() OVER (PARTITION BY line_scac ORDER BY snap_day DESC) AS rk
    FROM {{ this }}
  ) WHERE rk = 1
){% endif %}
SELECT d.line_scac, d.snap_day, d.bill_to, d.is_test
FROM d
{% if is_incremental() %}
LEFT JOIN cur AS c ON c.line_scac = d.line_scac
{% endif %}
WHERE d.rn = 1
{% if is_incremental() %}
  AND (c.line_scac IS NULL OR c.bill_to IS NOT d.bill_to OR c.is_test IS NOT d.is_test)
{% endif %}
 
-- task: visits_latest
-- One row per visit. Each column is the newest non-null value over all the rows of the visit, in
-- order of the yard update time (a real instant), then batch day, then load time. One pass: the
-- value is carried behind a fixed-width 50 character sort key and cut off again after the max.
WITH g AS (
  SELECT visit_gkey, min(eff_day) AS first_day,
         max(CASE WHEN unit_nbr IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || unit_nbr END) AS m_unit, max(CASE WHEN line_scac IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || line_scac END) AS m_line, max(CASE WHEN state_norm IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || state_norm END) AS m_state,
         max(CASE WHEN tariff_cd IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || tariff_cd END) AS m_tariff, max(CASE WHEN dsch_utc IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || dsch_utc END) AS m_dsch, max(CASE WHEN gate_utc IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || gate_utc END) AS m_gate,
         max(CASE WHEN booking_ref IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || booking_ref END) AS m_book
  FROM unit_visit_history
  GROUP BY visit_gkey
),
v AS (
  SELECT visit_gkey, first_day,
         substr(m_unit, 51) AS unit_nbr, substr(m_line, 51) AS line_scac, substr(m_state, 51) AS state_v,
         substr(m_tariff, 51) AS tariff_cd, substr(m_dsch, 51) AS dsch_utc, substr(m_gate, 51) AS gate_out_time,
         substr(m_book, 51) AS booking_ref
  FROM g
)
SELECT visit_gkey, first_day, unit_nbr, line_scac,
       CASE state_v
         WHEN 'discharged' THEN 'discharged' WHEN 'discharge' THEN 'discharged' WHEN 'dischgd' THEN 'discharged'
         WHEN 'dischd' THEN 'discharged' WHEN 'disch' THEN 'discharged' WHEN 'unloaded' THEN 'discharged'
         WHEN 'held' THEN 'held' WHEN 'hold' THEN 'held' WHEN 'on_hold' THEN 'held' WHEN 'holding' THEN 'held'
         WHEN 'gated_out' THEN 'gated_out' WHEN 'gate_out' THEN 'gated_out' WHEN 'gatedout' THEN 'gated_out'
         WHEN 'gateout' THEN 'gated_out' WHEN 'gated' THEN 'gated_out' WHEN 'exited' THEN 'gated_out'
         WHEN 'exit' THEN 'gated_out' WHEN 'departed' THEN 'gated_out' WHEN 'out' THEN 'gated_out'
         WHEN 'transshipped' THEN 'transshipped' WHEN 'transhipped' THEN 'transshipped'
         WHEN 'transshipment' THEN 'transshipped' WHEN 'transship' THEN 'transshipped'
         WHEN 'tranship' THEN 'transshipped' WHEN 'trans' THEN 'transshipped' WHEN 'ts' THEN 'transshipped'
       END AS visit_state,
       tariff_cd, dsch_utc, gate_out_time, booking_ref
FROM v
 
-- task: visit_lines
-- Per visit: the bill-to party and test flag of its line on the terminal day it came off the ship.
-- The terminal day runs from 06:00 to 06:00 at UTC+8, which is the UTC clock shifted by 2 hours.
-- The stored state of the line on or before that day is used, else the earliest stored state.
WITH base AS (
  SELECT visit_gkey, line_scac, COALESCE(date(dsch_utc, '+2 hours'), first_day) AS d
  FROM visits_latest
  WHERE line_scac IS NOT NULL
),
snaps AS (
  SELECT line_scac, snap_day AS d, 0 AS ord, NULL AS visit_gkey
  FROM line_operator_history
  WHERE line_scac IN (SELECT line_scac FROM base)
),
evs AS (SELECT line_scac, d, 1 AS ord, visit_gkey FROM base),
u AS (SELECT * FROM snaps UNION ALL SELECT * FROM evs),
w AS (
  SELECT line_scac, d, ord, visit_gkey,
         max(CASE WHEN ord = 0 THEN d END)
           OVER (PARTITION BY line_scac ORDER BY d, ord ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS asof_d,
         min(CASE WHEN ord = 0 THEN d END) OVER (PARTITION BY line_scac) AS first_d
  FROM u
)
SELECT w.visit_gkey, s.bill_to, s.is_test
FROM w
LEFT JOIN line_operator_history AS s
       ON s.line_scac = w.line_scac AND s.snap_day = COALESCE(w.asof_d, w.first_d)
WHERE w.ord = 1
 
-- task: visit_days
-- One row per visit per charge day: the days charged and the tariff of that day. A restated day
-- (a row marked as restating it) wins over the rows it restates, so the day is replaced and not
-- added twice; otherwise the newest non-null value of the day is taken. The tariff of a row that
-- carries none is the latest tariff of the visit. One pass over the history.
WITH g AS (
  SELECT visit_gkey, eff_day,
         max(CASE WHEN days IS NOT NULL THEN CAST(restated AS TEXT) || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || CAST(days AS TEXT) END) AS m_days,
         max(CASE WHEN tariff_cd IS NOT NULL THEN CAST(restated AS TEXT) || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || tariff_cd END) AS m_tariff
  FROM unit_visit_history
  GROUP BY visit_gkey, eff_day
)
SELECT g.visit_gkey, g.eff_day,
       CAST(substr(g.m_days, 42) AS REAL) AS days,
       COALESCE(substr(g.m_tariff, 42), l.tariff_cd) AS tariff_cd
FROM g
LEFT JOIN visits_latest AS l ON l.visit_gkey = g.visit_gkey
WHERE g.m_days IS NOT NULL
 
-- task: visit_charges
-- Per visit: the days charged each day at the rate of that day, added up, and the part charged on
-- days up to the close. Amounts are integers in ten-thousandths of a dollar.
SELECT d.visit_gkey,
       sum(CAST(round(d.days * r.rate_i) AS INTEGER)) AS tot_i,
       sum(CASE WHEN d.eff_day <= '2026-10-19' THEN CAST(round(d.days * r.rate_i) AS INTEGER) ELSE 0 END) AS per_i
FROM visit_days AS d
LEFT JOIN tariff_day_rates AS r ON r.tariff_cd = d.tariff_cd AND r.day = d.eff_day
GROUP BY d.visit_gkey
 
-- task: tariff_day_rates
-- USD per charged day, in ten-thousandths, for each tariff and day a visit needs: the rate of the
-- latest effective day on or before it, so a rate applies until the next one starts.
WITH pairs AS (
  SELECT DISTINCT tariff_cd, eff_day AS day FROM visit_days WHERE tariff_cd IS NOT NULL
)
SELECT p.tariff_cd, p.day,
       (SELECT CAST(round(t.rate_usd * 10000) AS INTEGER) FROM tariff_rate_history AS t
        WHERE t.tariff_cd = p.tariff_cd AND t.eff_date <= p.day
        ORDER BY t.eff_date DESC LIMIT 1) AS rate_i
FROM pairs AS p
 
-- task: storage_charges
-- The target: one row per visit, visits of a test line left out. Amounts are rounded half away
-- from zero to cents in integer arithmetic.
SELECT v.visit_gkey,
       v.unit_nbr,
       v.visit_state,
       v.gate_out_time,
       v.booking_ref,
       printf('%.2f', (CASE WHEN COALESCE(c.tot_i, 0) < 0 THEN -((-COALESCE(c.tot_i, 0) + 50) / 100) ELSE (COALESCE(c.tot_i, 0) + 50) / 100 END) / 100.0) AS storage_usd,
       printf('%.2f', (CASE WHEN COALESCE(c.per_i, 0) < 0 THEN -((-COALESCE(c.per_i, 0) + 50) / 100) ELSE (COALESCE(c.per_i, 0) + 50) / 100 END) / 100.0) AS storage_in_period_usd,
       l.bill_to
FROM visits_latest AS v
LEFT JOIN visit_charges AS c ON c.visit_gkey = v.visit_gkey
LEFT JOIN visit_lines AS l ON l.visit_gkey = v.visit_gkey
WHERE COALESCE(l.is_test, 0) = 0
