SELECT transaction_id, user_id, product_id, quantity, transaction_date, product_name
FROM transactions AS t
INNER JOIN products AS p 
USING (product_id)
