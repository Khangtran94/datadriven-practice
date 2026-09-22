SELECT p.product_id, product_name
FROM products AS p
LEFT JOIN transactions AS t USING (product_id)
WHERE t.transaction_id IS NULL
