SELECT user_id, SUM(total_amount) AS total_spent
FROM transactions
WHERE extract(year from transaction_date) = '2026'
GROUP BY 1
ORDER By 2 desc
