SELECT product_name, SUM(total_amount), SUM(quantity)
FROM products 
INNER JOIN transactions 
USING (product_id)
GROUP BY 1
HAVING SUM(total_amount) > 100
ORDER BY 2 desc
