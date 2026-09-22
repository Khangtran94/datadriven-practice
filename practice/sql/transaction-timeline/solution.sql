SELECT username, MIN(transaction_date), max(transaction_date), SUM(total_amount) 
FROM users INNER JOIN transactions USING (user_id)
GROUP BY 1
