SELECT product_name, COUNT(transaction_id)
FROM products
INNER JOIN transactions 
USING (product_id)
GROUP BY 1
