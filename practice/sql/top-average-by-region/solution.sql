SELECT category, AVG(total_amount)
FROM transactions
JOIN products 
USING (product_id)
GROUP BY 1 
ORDER BY 2 DESC
LIMIT 3
