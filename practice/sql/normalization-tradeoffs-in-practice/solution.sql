SELECT category, SUM(quantity * price) AS total_revenue
FROM transactions 
INNER JOIN products USING (product_id)
GROUP BY 1
ORDER BY 1
