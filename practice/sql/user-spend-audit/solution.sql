SELECT SUM(total_amount) AS total_spend
FROM transactions
INNER JOIN products USING (product_id) 
INNER JOIN users USING (user_id)
WHERE username = 'alice' AND rating > 3 AND category = 'Electronics'
