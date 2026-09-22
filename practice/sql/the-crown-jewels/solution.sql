SELECT product_name, SUM(total_amount) AS total_revenue
FROM products 
INNER JOIN transactions 
USING (product_id)
GROUP BY 1 
ORDER BY 2 desc limit 5
