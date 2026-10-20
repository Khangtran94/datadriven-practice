# Week 5 Postgres port test (worked example)

- `gen.py`: synthetic raw_payments / raw_fx_rates / raw_merchants (all TEXT) built from the Week 5 README conditions.
  `SEED=7 python3 gen.py` prints row counts. It leaves out bare-time strings such as `12:30` on purpose:
  SQLite turns them into `2000-01-01 12:30:00`, Postgres gives NULL (an engine quirk, not a port bug).
- `run.py`: runs `gold_submit.sql` in SQLite and `Claude_gold_submit_Postgres.sql` in Postgres on the same data and compares
  `payments_history`, `fx_history`, `merchants_history` (ignoring `rk`) and `fct_payments` (per key, per column, zero tolerance).

Reproduce: start a local Postgres 16, set `PGPASSWORD`, `pip install psycopg2-binary`, then
`WEEK_DIR=weekly/week-05-the-close SEED=7 python3 run.py` (repeat with SEED=11 and 23).
Result for the committed port: 0 differing rows in every table, 0 column mismatches, on all 3 seeds
(about 6,000 raw payment rows, 310 fx rows, 1,700 merchant rows each).
