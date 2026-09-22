SELECT category, COUNT(transaction_id) AS transaction_count
FROM products
INNER JOIN transactions 
USING (product_id)
WHERE extract(year from transaction_date) = 2026
GROUP BY 1
QUALIFY DENSE_RANK() OVER(ORDER BY transaction_count DESC) = 1
