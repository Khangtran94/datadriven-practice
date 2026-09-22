SELECT product_id, SUM(total_amount)
FROM transactions
WHERE EXTRACT(month from transaction_date) between 1 and 6
GROUP BY 1 
ORDER BY 2 DESC
LIMIT 5
