SELECT product_name, COUNT(transactions.transaction_id) AS transaction_count
FROM products
INNER JOIN transactions 
USING (product_id)
GROUP BY 1
