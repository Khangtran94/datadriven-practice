SELECT product_id,
       Lower(product_name) AS product_name,
       SUM(total_amount) / SUM(quantity) AS avg_unit_price
FROM products
INNER JOIN transactions
USING (product_id)
GROUP BY 1,2
HAVING avg_unit_price >= 100
