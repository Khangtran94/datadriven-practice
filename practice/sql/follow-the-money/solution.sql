SELECT user_id, SUM(total_amount)
FROM transactions
WHERE extract(year from transaction_date) = 2026
GROUP BY 1 
ORDER BY 2 desc
