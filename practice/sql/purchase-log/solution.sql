SELECT username, total_amount, transaction_date
FROM users INNER JOIN transactions USING (user_id)
WHERE total_amount > 50
