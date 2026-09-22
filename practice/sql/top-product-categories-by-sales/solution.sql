SELECT category, SUM(total_amount)
FROM products
INNER JOIN transactions USING (product_id)
GROUP BY 1 ORDEr By 2 DESC
