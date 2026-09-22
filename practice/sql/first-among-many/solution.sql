SELECT account_status, category, COUNT(transaction_id) AS purchase_count
FROM users 
INNER JOIN transactions USING (user_id)
INNER JOIN products USING (product_id)
GROUP BY 1,2
QUALIFY DENSE_RANK() OVER(PARTITION BY account_status ORDER BY purchase_count DESC) = 1
