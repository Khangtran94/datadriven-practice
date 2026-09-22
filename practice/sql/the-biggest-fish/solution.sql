SELECT category, user_id, SUM(total_amount) AS total_spent
FROM transactions 
INNER JOIN products
USING (product_id)
GROUP BY 1,2 
QUALIFY RANK() OVER(PARTITION BY category ORDER BY total_spent DESC) = 1
