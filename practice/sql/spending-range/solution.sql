with newuser AS
(SELECT user_id, username, COUNT(transaction_id) AS cnt
FROM users
INNER JOIN transactions USING (user_id)
GROUP BY 1,2 
HAVING cnt > 1)

SELECT username, MIN(total_amount) AS low,
      max(total_amount) AS high,
      max(total_amount) - min(total_amount)
FROM users
INNER JOIN transactions USING (user_id)
-- WHERE username EXISTS (SELECT 1 FROM newuser WHERE newuser.username = users.username)
GROUP BY 1
