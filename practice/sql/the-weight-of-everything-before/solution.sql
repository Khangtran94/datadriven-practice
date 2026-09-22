SELECT user_id, transaction_date,
    SUM(total_amount) OVER(PARTITION BY user_id ORDER BY transaction_date) AS running_total
FROM transactions
