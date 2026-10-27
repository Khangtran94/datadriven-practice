# Week 6 SQL week: test harness (worked example)

Used for `the-dwell` (3 history tasks with incremental merge + 6 table tasks). Reproduce with a local Postgres 16
(trust auth, role `claude`, database `dwell`) and `pip install psycopg2-binary`. Paths in `run.py` point at the repo clone; edit `REPO`.

- `gen.py`: synthetic raw tables (all TEXT) from the README conditions. Each row has a hidden `night`; `RATE_FMT=messy` adds shapes
  that are NOT in the README (use only to stress a port, never to judge the user's code).
- `run.py`: runs a DAG file night by night: landing windows (unit_visit 7 nights, tariff 2, line_operator 1), renders the
  `{% if is_incremental() %}` / `{{ this }}` markers, merges by unique key, then builds the table tasks. Engines: SQLite, Postgres.
  `python3 run.py gold|user|pg <file>`.
- `ablate.py`: applies ONE fix at a time to the user's dag.sql (string patches, each asserted to match once) and counts how many
  rows match gold per column. This is how each section of the analysis gets its `[estimate]` proof.
- `build_port.py` + `header.sql`: generates the Postgres port; repeated per-column blocks come from one template so they cannot drift.
- `cmp_pg_gold.py`: gold (SQLite) vs port (Postgres), every table, per key and per column, zero tolerance, 3 seeds.

Result for the committed port: 0 differences in all 9 tables, seeds 7/11/23 (plain and messy rate formats).
