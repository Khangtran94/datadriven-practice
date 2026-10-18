/* dag.yml
dag: the_close
schedule: nightly
tasks:                      # depends_on = the edges; materialized: table | incremental | snapshot | view | test | sensor
  payments_history:
    materialized: incremental
    depends_on: [raw_payments]
  fx_rates_history:
    materialized: incremental
    depends_on: [raw_fx_rates]
  merchants_history:
    materialized: incremental
    depends_on: [raw_merchants]
  fct_payments:
    materialized: table
    depends_on: [payments_history, fx_rates_history, merchants_history]
*/

-- each file is 1 SELECT, built into a table of the file's name; dag.yml says what it runs after

-- task: payments_history
SELECT *
FROM raw_payments

-- task: fx_rates_history
SELECT * FROM raw_fx_rates;

-- task: merchants_history
SELECT * FROM raw_merchants;

-- task: fct_payments
SELECT payment_id,
       status,
       amount AS amount_usd,
       settled AS settled_usd,
       settled AS settled_in_period_usd,
       captured_at,
       json_extract(metadata, '$.order_ref') AS order_ref,
       NULL AS merchant_country
FROM payments_history;   -- 1 row per key: a second row for the same key costs 2
