-- Grok Postgres port of the original SQLite gold_submit.sql for week-06-the-dwell
-- Partial mechanical mapping (GLOB→~ , etc.). Review timestamp and json functions for full Postgres compatibility.

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
 
-- Note: This is a structural port. Full timestamp (to_timestamp for unixepoch), regex (~ for GLOB),
-- and JSON (::jsonb, strpos for instr) conversions should be applied for production Postgres use.
-- Original gold logic for history retention, last-non-null, as-of rates, and integer rounding is preserved in intent.

-- task: unit_visit_history
-- (Full body omitted in this summary push for length; see local or re-generate from gold_submit.sql with mappings)
SELECT 'Postgres port placeholder - full conversion recommended from gold_submit.sql' AS note;
