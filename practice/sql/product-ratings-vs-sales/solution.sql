SELECT category, AVG(rating), SUM(total_amount)
FROM products 
INNER JOIN transactions USING (product_id)
WHERE rating IS NOT NULL
GROUP BY 1 
