SELECT username, 
    COUNT(transaction_id) AS txn_count,
    DENSE_RANK() OVER(ORDER BY COUNT(transaction_id) DESC) AS tier
FROM users
INNER JOIN transactions
USING (user_id)
WHERE total_amount > 0
GROUP BY 1
QUALIFY tier <= 2
