WITH max_date AS (
    SELECT MAX(transaction_date) AS max_date
    FROM transactions
)

SELECT
    COUNT_IF(t.transaction_date >= date_sub(m.max_date, 30)) AS last_30_days,
    COUNT_IF(t.transaction_date >= date_sub(m.max_date, 180)) AS last_180_days,
    COUNT(*) AS all_time
FROM transactions t
CROSS JOIN max_date m;
