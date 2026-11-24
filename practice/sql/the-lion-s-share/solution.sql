SELECT category, SUM(total_amount) AS total_revenue,
    COUNT(transaction_id) AS transaction_count
FROM products
INNER JOIN transactions
USING (product_id)
GROUP BY 1
ORDER BY 2 desc
