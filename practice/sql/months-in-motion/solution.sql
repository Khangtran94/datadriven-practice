SELECT extract(month from transaction_date), COUNT(DISTINCT user_id), COUNT(*)
FROM transactions
GROUP BY 1
