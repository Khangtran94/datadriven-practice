SELECT username, COUNT(transaction_id) AS purchase_count
FROM users INNER JOIN transactions USING (user_id)
GROUP BY 1 
HAVING COUNT(transaction_id) > 2
ORDER BY 2 DESC
