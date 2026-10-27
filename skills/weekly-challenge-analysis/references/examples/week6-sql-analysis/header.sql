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
