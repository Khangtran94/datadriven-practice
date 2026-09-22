SELECT product_name, COALESCE(SUM(total_amount),0) AS electronics_total
FROM products AS p 
LEFT JOIN transactions AS t
ON p.product_id = t.product_id AND p.category = 'Electronics'
GROUP BY 1
ORDER BY 2 DESC
