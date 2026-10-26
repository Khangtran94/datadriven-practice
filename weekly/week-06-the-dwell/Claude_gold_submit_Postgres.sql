/* Claude_gold_submit_Postgres.sql
   PostgreSQL 16+ port of gold_submit.sql (the top-1 submission, written for SQLite).
   Same DAG, same logic, same task order, same output columns. Only the dialect changed. Nothing in the gold was fixed or improved.

   Assumptions
   - unit_visit, tariff_rate, line_operator exist and every column is TEXT (a text dump landed as-is).
   - PostgreSQL 16 or newer: pg_input_is_valid() is used so a bad date or JSON becomes NULL instead of an error
     (SQLite's strftime()/date()/json_valid() return NULL on bad input; a Postgres cast raises and stops the whole task).
   - Plain SQL only: no CREATE FUNCTION, no DO block. Each task is one WITH ... SELECT, built in steps:
       b = trim the text, c = "null"/"N/A"/"-" become NULL, n = prepare the text, p = parse/cast, final SELECT = clean columns.
   - The {% if is_incremental() %} and {{ this }} markers are kept exactly as in the gold: the DAG runner fills them in.
   - Money is NUMERIC (exact) where the gold used REAL; the gold already rounds in integer ten-thousandths, so results are the same.
   - Text timestamps stay text in the form 2026-10-01T03:30:00Z, as in the gold, and are compared with COLLATE "C" (byte order, like SQLite).
   - Not copied from SQLite on purpose: a bare time such as "12:30" or a date like 2026-02-30 is read by SQLite (as 2000-01-01 12:30 and
     2026-03-02) but gives NULL here. A JSON object or array used as booking_ref is returned by SQLite as compact JSON text and by Postgres
     with spaces after ":" and ",". Neither shape is described in the README.

   SQLite -> Postgres cheat sheet
     trim(x)                         -> btrim(x, ' ')        (SQLite trim() with no 2nd argument trims spaces only)
     char(92) || 'N'                 -> '\N'                 (backslash + N, a null marker some tools write)
     x GLOB '[0-9]*'                 -> x ~ '^[0-9]'         (regex instead of glob; "NOT GLOB '*[^0-9]*'" -> x ~ '^[0-9]+$')
     instr(a, b)                     -> strpos(a, b)
     strftime('%Y-%m-%dT%H:%M:%SZ', x) -> regex check + pg_input_is_valid() + ::timestamptz AT TIME ZONE 'UTC' + to_char()
     strftime(..., n, 'unixepoch')   -> to_char(to_timestamp(n) AT TIME ZONE 'UTC', ...)
     date(x), date(x, '-1 day')      -> regex check + pg_input_is_valid() + ::date, minus 1
     date(x, '+2 hours')             -> (x::timestamp + interval '2 hours')
     json_valid / json_extract       -> pg_input_is_valid(x, 'jsonb') / ->>
     max(key || value) + substr      -> same, with COLLATE "C" so the text order is the same as SQLite
     ORDER BY x DESC (NULL smallest) -> ORDER BY x DESC NULLS LAST   (Postgres puts NULL first on DESC)
     a IS NOT b                      -> a IS DISTINCT FROM b
     printf('%.2f', x)               -> (x)::numeric(20, 2)::text

dag.yml
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

-- task: unit_visit_history
-- Every distinct source row of the change log, cleaned, kept across runs because the landing
-- forgets after 7 nights. A row already held is skipped before any cleaning. Rows are never
-- collapsed here: each system fills only the columns it owns, so the day level and visit level
-- views below pick the newest non-null value of each column.
-- Steps: b = trim + row key, c = null markers -> NULL, n = text to parse, p = parse, k/q/bd = find booking_ref in text,
--        e = clean columns, d = booking_ref null markers + de-duplicate.
WITH b AS (
  SELECT r.src_key,
    btrim(r.visit_gkey, ' ') AS gk, btrim(r.unit_nbr, ' ') AS unit_raw, btrim(r.line_scac, ' ') AS scac,
    btrim(r.visit_state, ' ') AS st, btrim(r.tariff_cd, ' ') AS tcd, btrim(r.days_chg, ' ') AS days_t,
    btrim(r.dsch_time, ' ') AS d_at, btrim(r.gate_out_time, ' ') AS g_at, btrim(r.last_upd_time, ' ') AS u_at,
    btrim(r._batch_id, ' ') AS b_id, btrim(r._restated_day, ' ') AS rest, btrim(r._loaded_at, ' ') AS l_at,
    r.remarks
  FROM (
    SELECT u.*,
           COALESCE(u.visit_gkey, '') || '|' || COALESCE(u._batch_id, '') || '|' || COALESCE(u._restated_day, '') || '|' || COALESCE(u._loaded_at, '') || '|' || COALESCE(u.last_upd_time, '') || '|' || COALESCE(u.days_chg, '') || '|' || COALESCE(u.visit_state, '') || '|' || COALESCE(u.gate_out_time, '') || '|' || COALESCE(u.unit_nbr, '') AS src_key
    FROM unit_visit AS u
  ) AS r
{% if is_incremental() %}
  LEFT JOIN {{ this }} AS x ON x.src_key = r.src_key
  WHERE x.src_key IS NULL
{% endif %}
),
c AS (
  SELECT src_key, remarks,
    CASE WHEN upper(gk) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE gk END AS gk,
    CASE WHEN upper(unit_raw) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE unit_raw END AS unit_raw,
    CASE WHEN upper(scac) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE scac END AS scac,
    CASE WHEN upper(st) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE st END AS st,
    CASE WHEN upper(tcd) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE tcd END AS tcd,
    CASE WHEN upper(days_t) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE days_t END AS days_t,
    CASE WHEN upper(d_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE d_at END AS d_at,
    CASE WHEN upper(g_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE g_at END AS g_at,
    CASE WHEN upper(u_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE u_at END AS u_at,
    CASE WHEN upper(b_id) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE b_id END AS b_id,
    CASE WHEN upper(rest) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE rest END AS rest,
    CASE WHEN upper(l_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE l_at END AS l_at
  FROM b
),
n AS (
  SELECT c.*,
    CASE WHEN d_at IS NULL THEN NULL
         WHEN d_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN d_at LIKE '%:%' AND d_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN d_at || ':00'
         WHEN d_at LIKE '%:%' AND d_at ~ '[0-9][+-][0-9]{4}$' THEN left(d_at, length(d_at) - 2) || ':' || right(d_at, 2)
         WHEN d_at LIKE '%:%' AND d_at ~ '[0-9][+-][0-9]{2}$' THEN d_at || ':00'
         WHEN d_at LIKE '%:%' AND d_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN d_at
         WHEN d_at LIKE '%:%' AND d_at ~ '[Zz]$' THEN d_at
         WHEN d_at LIKE '%:%' AND d_at ILIKE '% UTC' THEN replace(d_at, ' UTC', '')
         ELSE d_at || '+08:00' END AS d_s,
    CASE WHEN g_at IS NULL THEN NULL
         WHEN g_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN g_at LIKE '%:%' AND g_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN g_at || ':00'
         WHEN g_at LIKE '%:%' AND g_at ~ '[0-9][+-][0-9]{4}$' THEN left(g_at, length(g_at) - 2) || ':' || right(g_at, 2)
         WHEN g_at LIKE '%:%' AND g_at ~ '[0-9][+-][0-9]{2}$' THEN g_at || ':00'
         WHEN g_at LIKE '%:%' AND g_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN g_at
         WHEN g_at LIKE '%:%' AND g_at ~ '[Zz]$' THEN g_at
         WHEN g_at LIKE '%:%' AND g_at ILIKE '% UTC' THEN replace(g_at, ' UTC', '')
         ELSE g_at || '+08:00' END AS g_s,
    CASE WHEN u_at IS NULL THEN NULL
         WHEN u_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN u_at LIKE '%:%' AND u_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN u_at || ':00'
         WHEN u_at LIKE '%:%' AND u_at ~ '[0-9][+-][0-9]{4}$' THEN left(u_at, length(u_at) - 2) || ':' || right(u_at, 2)
         WHEN u_at LIKE '%:%' AND u_at ~ '[0-9][+-][0-9]{2}$' THEN u_at || ':00'
         WHEN u_at LIKE '%:%' AND u_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN u_at
         WHEN u_at LIKE '%:%' AND u_at ~ '[Zz]$' THEN u_at
         WHEN u_at LIKE '%:%' AND u_at ILIKE '% UTC' THEN replace(u_at, ' UTC', '')
         ELSE u_at || '+08:00' END AS u_s,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN l_at LIKE '%:%' AND l_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{4}$' THEN left(l_at, length(l_at) - 2) || ':' || right(l_at, 2)
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ~ '[Zz]$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ILIKE '% UTC' THEN replace(l_at, ' UTC', '')
         ELSE l_at END AS l_s
  FROM c
),
p AS (
  SELECT n.*,
    CASE WHEN d_at IS NULL THEN NULL
         WHEN d_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((d_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN d_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(d_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN d_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(d_s, 'timestamptz')
              THEN to_char(date_trunc('second', d_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN d_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(d_s, 'timestamp')
              THEN to_char(date_trunc('second', d_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS dsch_utc,
    CASE WHEN g_at IS NULL THEN NULL
         WHEN g_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((g_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN g_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(g_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN g_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(g_s, 'timestamptz')
              THEN to_char(date_trunc('second', g_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN g_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(g_s, 'timestamp')
              THEN to_char(date_trunc('second', g_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS gate_utc,
    CASE WHEN u_at IS NULL THEN NULL
         WHEN u_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((u_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN u_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(u_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN u_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(u_s, 'timestamptz')
              THEN to_char(date_trunc('second', u_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN u_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(u_s, 'timestamp')
              THEN to_char(date_trunc('second', u_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS upd_utc,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((l_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(l_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(l_s, 'timestamptz')
              THEN to_char(date_trunc('second', l_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(l_s, 'timestamp')
              THEN to_char(date_trunc('second', l_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS loaded_utc,
    CASE WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(b_id, 'date') THEN b_id
         WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(b_id, 'timestamptz') THEN to_char(b_id::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD')
         WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(b_id, 'timestamp') THEN to_char(b_id::timestamp, 'YYYY-MM-DD')
         END AS batch_day,
    CASE WHEN rest ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(rest, 'date') THEN rest
         WHEN rest ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(rest, 'timestamptz') THEN to_char(rest::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD')
         WHEN rest ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(rest, 'timestamp') THEN to_char(rest::timestamp, 'YYYY-MM-DD')
         END AS rest_day,
    CASE WHEN gk ~ '^[0-9]+$' THEN gk
         WHEN gk ~ '^[0-9]+\.0$' THEN substr(gk, 1, length(gk) - 2) END AS visit_gkey,
    -- where the booking_ref key sits in the remarks text (used only when remarks is not valid JSON)
    CASE WHEN strpos(remarks, '"booking_ref"') > 0 THEN strpos(remarks, '"booking_ref"') + 13
         WHEN strpos(remarks, '"bookingRef"') > 0 THEN strpos(remarks, '"bookingRef"') + 12 END AS kpos
  FROM n
),
k AS (
  SELECT p.*,
         CASE WHEN kpos IS NOT NULL AND substr(ltrim(substr(remarks, kpos), ' '), 1, 1) = ':'
              THEN ltrim(substr(ltrim(substr(remarks, kpos), ' '), 2), ' ') END AS qv
  FROM p
  WHERE visit_gkey IS NOT NULL
),
bd AS (
  SELECT k.*, CASE WHEN substr(qv, 1, 1) = '"' THEN substr(qv, 2) END AS body,
         pg_input_is_valid(remarks, 'jsonb') AS remarks_ok
  FROM k
),
e AS (
  SELECT src_key, visit_gkey,
         upper(replace(replace(replace(replace(unit_raw, ' ', ''), '-', ''), '_', ''), '.', '')) AS unit_c,
         upper(scac) AS line_scac,
         lower(replace(replace(st, ' ', '_'), '-', '_')) AS state_norm,
         upper(tcd) AS tariff_cd,
         CASE WHEN days_t ~ '^-?([0-9]+\.?[0-9]*|\.[0-9]+)$' THEN days_t::numeric END AS days,
         dsch_utc, gate_utc, upd_utc, loaded_utc, batch_day, rest_day,
         CASE WHEN remarks_ok THEN COALESCE(
                 CASE jsonb_typeof(remarks::jsonb -> 'booking_ref') WHEN 'boolean' THEN CASE WHEN (remarks::jsonb ->> 'booking_ref') = 'true' THEN '1' ELSE '0' END
                      ELSE remarks::jsonb ->> 'booking_ref' END,
                 CASE jsonb_typeof(remarks::jsonb -> 'bookingRef') WHEN 'boolean' THEN CASE WHEN (remarks::jsonb ->> 'bookingRef') = 'true' THEN '1' ELSE '0' END
                      ELSE remarks::jsonb ->> 'bookingRef' END)
              WHEN strpos(body, '"') > 0 THEN substr(body, 1, strpos(body, '"') - 1) END AS ref_raw
  FROM bd
),
d AS (
  SELECT e.*,
         CASE WHEN unit_c ~ '^[A-Z]{4}[0-9]{7}$' THEN unit_c END AS unit_nbr,
         COALESCE(rest_day, batch_day, to_char(substr(loaded_utc, 1, 10)::date - 1, 'YYYY-MM-DD')) AS eff_day,
         CASE WHEN rest_day IS NOT NULL THEN 1 ELSE 0 END AS restated,
         CASE WHEN upper(btrim(ref_raw, ' ')) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', 'NA', '-', '--', 'NIL', 'UNDEFINED', '?', 'UNKNOWN') THEN NULL ELSE btrim(ref_raw, ' ') END AS booking_ref,
         row_number() OVER (PARTITION BY src_key ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn
  FROM e
)
SELECT src_key, visit_gkey, eff_day, batch_day, unit_nbr, line_scac, state_norm, tariff_cd, days,
       dsch_utc, gate_utc, upd_utc, loaded_utc, booking_ref, restated
FROM d
WHERE rn = 1 AND eff_day IS NOT NULL


-- task: tariff_rate_history
-- One rate per tariff per effective day, kept across runs because the landing keeps 2 nights and
-- later nights carry only the changes. A rate sent again for the same day replaces the earlier one.
-- Steps: b = trim, c = null markers -> NULL, n = prepare text, p = parse, d = newest per tariff + day.
WITH b AS (
  SELECT btrim(tariff_cd, ' ') AS tariff_cd, btrim(eff_date, ' ') AS eff_date, btrim(rate_usd, ' ') AS rate_usd,
         btrim(_loaded_at, ' ') AS l_at
  FROM tariff_rate
),
c AS (
  SELECT CASE WHEN upper(tariff_cd) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE tariff_cd END AS tariff_cd,
         CASE WHEN upper(eff_date) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE eff_date END AS eff_date,
         CASE WHEN upper(rate_usd) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE rate_usd END AS rate_usd,
         CASE WHEN upper(l_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE l_at END AS l_at
  FROM b
),
n AS (
  SELECT c.*,
         -- decimal comma ("12,50") -> point; thousands comma ("1,234.50") dropped; currency sign dropped
         CASE WHEN rate_usd IS NULL THEN NULL
              WHEN rate_usd LIKE '%,%' AND rate_usd NOT LIKE '%.%' THEN replace(replace(rate_usd, ',', '.'), '$', '')
              ELSE replace(replace(rate_usd, ',', ''), '$', '') END AS rate_t,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN l_at LIKE '%:%' AND l_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{4}$' THEN left(l_at, length(l_at) - 2) || ':' || right(l_at, 2)
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ~ '[Zz]$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ILIKE '% UTC' THEN replace(l_at, ' UTC', '')
         ELSE l_at END AS l_s
  FROM c
),
p AS (
  SELECT upper(tariff_cd) AS tariff_cd,
    CASE WHEN eff_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(eff_date, 'date') THEN eff_date
         WHEN eff_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(eff_date, 'timestamptz') THEN to_char(eff_date::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD')
         WHEN eff_date ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(eff_date, 'timestamp') THEN to_char(eff_date::timestamp, 'YYYY-MM-DD')
         END AS eff_date,
         rate_t,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((l_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(l_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(l_s, 'timestamptz')
              THEN to_char(date_trunc('second', l_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(l_s, 'timestamp')
              THEN to_char(date_trunc('second', l_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS loaded_utc
  FROM n
),
r AS (
  SELECT tariff_cd, eff_date, substring(rate_t from '^[0-9]+(?:\.[0-9]*)?')::numeric AS rate_usd, loaded_utc
  FROM p
  WHERE rate_t ~ '^[0-9][0-9.]*$' AND tariff_cd IS NOT NULL AND eff_date IS NOT NULL
),
d AS (
  SELECT r.*, row_number() OVER (PARTITION BY tariff_cd, eff_date ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn FROM r
)
SELECT d.tariff_cd, d.eff_date, d.rate_usd, d.loaded_utc
FROM d
{% if is_incremental() %}
LEFT JOIN {{ this }} AS o ON o.tariff_cd = d.tariff_cd AND o.eff_date = d.eff_date
{% endif %}
WHERE d.rn = 1
{% if is_incremental() %}
  AND (o.tariff_cd IS NULL OR COALESCE(d.loaded_utc, '') COLLATE "C" >= COALESCE(o.loaded_utc, '') COLLATE "C")
{% endif %}


-- task: line_operator_history
-- A shipping line row is stored when its bill-to party or test flag differs from the latest one
-- held. The landing keeps only the latest copy, so this is the only record of earlier states.
-- Steps: b = trim, c = null markers -> NULL, n = prepare text, p = parse, d = newest per line + day.
WITH b AS (
  SELECT btrim(line_scac, ' ') AS line_scac, btrim(_batch_id, ' ') AS b_id, btrim(bill_to, ' ') AS bill_to,
         btrim(test_flag, ' ') AS test_flag, btrim(_loaded_at, ' ') AS l_at
  FROM line_operator
),
c AS (
  SELECT CASE WHEN upper(line_scac) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE line_scac END AS line_scac,
         CASE WHEN upper(b_id) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE b_id END AS b_id,
         CASE WHEN upper(bill_to) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE bill_to END AS bill_to,
         CASE WHEN upper(test_flag) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE test_flag END AS test_flag,
         CASE WHEN upper(l_at) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', '-') THEN NULL ELSE l_at END AS l_at
  FROM b
),
n AS (
  SELECT c.*,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]+$' THEN NULL                                   -- all digits: epoch, handled in step p
         WHEN l_at LIKE '%:%' AND l_at ~ ':[0-9]{2}[+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{4}$' THEN left(l_at, length(l_at) - 2) || ':' || right(l_at, 2)
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}$' THEN l_at || ':00'
         WHEN l_at LIKE '%:%' AND l_at ~ '[0-9][+-][0-9]{2}:[0-9]{2}$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ~ '[Zz]$' THEN l_at
         WHEN l_at LIKE '%:%' AND l_at ILIKE '% UTC' THEN replace(l_at, ' UTC', '')
         ELSE l_at END AS l_s
  FROM c
),
m AS (
  SELECT upper(line_scac) AS line_scac,
    CASE WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' AND pg_input_is_valid(b_id, 'date') THEN b_id
         WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(b_id, 'timestamptz') THEN to_char(b_id::timestamptz AT TIME ZONE 'UTC', 'YYYY-MM-DD')
         WHEN b_id ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(b_id, 'timestamp') THEN to_char(b_id::timestamp, 'YYYY-MM-DD')
         END AS snap_day,
         CASE WHEN upper(bill_to) IN ('', 'NULL', '\N', 'NONE', 'NAN', 'N/A', 'NA', '-', '--', 'NIL', 'UNDEFINED', '?', 'UNKNOWN') THEN NULL ELSE upper(bill_to) END AS bill_to,
         CASE WHEN upper(test_flag) IN ('Y', 'YES', 'TRUE', '1', 'T') THEN 1
              WHEN upper(test_flag) IN ('N', 'NO', 'FALSE', '0', 'F') THEN 0 END AS is_test,
    CASE WHEN l_at IS NULL THEN NULL
         WHEN l_at ~ '^[0-9]{13}$' THEN to_char(to_timestamp((l_at::bigint / 1000)::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_at ~ '^[0-9]{10}$' THEN to_char(to_timestamp(l_at::bigint::double precision) AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?(Z|z|[+-][0-9]{2}:[0-9]{2})$' AND pg_input_is_valid(l_s, 'timestamptz')
              THEN to_char(date_trunc('second', l_s::timestamptz AT TIME ZONE 'UTC'), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         WHEN l_s ~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}[T ][0-9]{2}:[0-9]{2}(:[0-9]{2}(\.[0-9]+)?)?$' AND pg_input_is_valid(l_s, 'timestamp')
              THEN to_char(date_trunc('second', l_s::timestamp), 'YYYY-MM-DD"T"HH24:MI:SS"Z"')
         END AS loaded_utc
  FROM n
),
d AS (
  SELECT line_scac, snap_day, bill_to, is_test,
         row_number() OVER (PARTITION BY line_scac, snap_day ORDER BY loaded_utc COLLATE "C" DESC NULLS LAST) AS rn
  FROM m
  WHERE line_scac IS NOT NULL AND snap_day IS NOT NULL
){% if is_incremental() %},
cur AS (
  SELECT line_scac, bill_to, is_test FROM (
    SELECT line_scac, bill_to, is_test,
           row_number() OVER (PARTITION BY line_scac ORDER BY snap_day COLLATE "C" DESC) AS rk
    FROM {{ this }}
  ) AS ranked WHERE rk = 1
){% endif %}
SELECT d.line_scac, d.snap_day, d.bill_to, d.is_test
FROM d
{% if is_incremental() %}
LEFT JOIN cur AS c ON c.line_scac = d.line_scac
{% endif %}
WHERE d.rn = 1
{% if is_incremental() %}
  AND (c.line_scac IS NULL OR c.bill_to IS DISTINCT FROM d.bill_to OR c.is_test IS DISTINCT FROM d.is_test)
{% endif %}


-- task: visits_latest
-- One row per visit. Each column is the newest non-null value over all the rows of the visit, in
-- order of the yard update time (a real instant), then batch day, then load time. One pass: the
-- value is carried behind a fixed-width 50 character sort key and cut off again after the max.
WITH g AS (
  SELECT visit_gkey, min(eff_day COLLATE "C") AS first_day,
         max(CASE WHEN unit_nbr IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || unit_nbr END COLLATE "C") AS m_unit,
         max(CASE WHEN line_scac IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || line_scac END COLLATE "C") AS m_line,
         max(CASE WHEN state_norm IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || state_norm END COLLATE "C") AS m_state,
         max(CASE WHEN tariff_cd IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || tariff_cd END COLLATE "C") AS m_tariff,
         max(CASE WHEN dsch_utc IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || dsch_utc END COLLATE "C") AS m_dsch,
         max(CASE WHEN gate_utc IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || gate_utc END COLLATE "C") AS m_gate,
         max(CASE WHEN booking_ref IS NOT NULL THEN COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(batch_day, '0000-00-00') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || booking_ref END COLLATE "C") AS m_book
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
  SELECT visit_gkey, line_scac,
         COALESCE(to_char(substr(dsch_utc, 1, 19)::timestamp + interval '2 hours', 'YYYY-MM-DD'), first_day) AS d
  FROM visits_latest
  WHERE line_scac IS NOT NULL
),
snaps AS (
  SELECT line_scac, snap_day AS d, 0 AS ord, NULL::text AS visit_gkey
  FROM line_operator_history
  WHERE line_scac IN (SELECT line_scac FROM base)
),
evs AS (SELECT line_scac, d, 1 AS ord, visit_gkey FROM base),
u AS (SELECT * FROM snaps UNION ALL SELECT * FROM evs),
w AS (
  SELECT line_scac, d, ord, visit_gkey,
         max(CASE WHEN ord = 0 THEN d END COLLATE "C")
           OVER (PARTITION BY line_scac ORDER BY d COLLATE "C", ord ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS asof_d,
         min(CASE WHEN ord = 0 THEN d END COLLATE "C") OVER (PARTITION BY line_scac) AS first_d
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
-- days is carried as text like SQLite prints a REAL (3.0, 1.5, -2.0) so the tie-break between rows with the same time is the same.
WITH g AS (
  SELECT visit_gkey, eff_day,
         max(CASE WHEN days IS NOT NULL THEN restated::text || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') ||
                   CASE WHEN days = trunc(days) THEN trunc(days)::bigint::text || '.0' ELSE trim_scale(days)::text END END COLLATE "C") AS m_days,
         max(CASE WHEN tariff_cd IS NOT NULL THEN restated::text || COALESCE(upd_utc, '0000-00-00T00:00:00Z') || COALESCE(loaded_utc, '0000-00-00T00:00:00Z') || tariff_cd END COLLATE "C") AS m_tariff
  FROM unit_visit_history
  GROUP BY visit_gkey, eff_day
)
SELECT g.visit_gkey, g.eff_day,
       substr(g.m_days, 42)::numeric AS days,
       COALESCE(substr(g.m_tariff, 42), l.tariff_cd) AS tariff_cd
FROM g
LEFT JOIN visits_latest AS l ON l.visit_gkey = g.visit_gkey
WHERE g.m_days IS NOT NULL

-- task: visit_charges
-- Per visit: the days charged each day at the rate of that day, added up, and the part charged on
-- days up to the close. Amounts are integers in ten-thousandths of a dollar.
SELECT d.visit_gkey,
       sum(round(d.days * r.rate_i)::bigint)::bigint AS tot_i,
       sum(CASE WHEN d.eff_day <= '2026-10-19' THEN round(d.days * r.rate_i)::bigint ELSE 0 END)::bigint AS per_i
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
       (SELECT round(t.rate_usd * 10000)::bigint FROM tariff_rate_history AS t
        WHERE t.tariff_cd = p.tariff_cd AND t.eff_date COLLATE "C" <= p.day COLLATE "C"
        ORDER BY t.eff_date COLLATE "C" DESC LIMIT 1) AS rate_i
FROM pairs AS p

-- task: storage_charges
-- The target: one row per visit, visits of a test line left out. Amounts are rounded half away
-- from zero to cents in integer arithmetic (tot_i and per_i are bigint, so "/" is integer division).
SELECT v.visit_gkey,
       v.unit_nbr,
       v.visit_state,
       v.gate_out_time,
       v.booking_ref,
       ((CASE WHEN COALESCE(c.tot_i, 0) < 0 THEN -((-COALESCE(c.tot_i, 0) + 50) / 100) ELSE (COALESCE(c.tot_i, 0) + 50) / 100 END) / 100.0)::numeric(20, 2)::text AS storage_usd,
       ((CASE WHEN COALESCE(c.per_i, 0) < 0 THEN -((-COALESCE(c.per_i, 0) + 50) / 100) ELSE (COALESCE(c.per_i, 0) + 50) / 100 END) / 100.0)::numeric(20, 2)::text AS storage_in_period_usd,
       l.bill_to
FROM visits_latest AS v
LEFT JOIN visit_charges AS c ON c.visit_gkey = v.visit_gkey
LEFT JOIN visit_lines AS l ON l.visit_gkey = v.visit_gkey
WHERE COALESCE(l.is_test, 0) = 0
