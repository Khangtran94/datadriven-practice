with total AS
(SELECT username, SUM(total_amount) AS spend
FROM users
INNER JOIN transactions
USING (user_id) 
GROUP By username)

SELECT transaction_id, username, total_amount,
      ROUND(total_amount / spend,3) AS spend_share
FROM transactions
INNER JOIN users
USING (user_id)
INNER JOIN total
USING (username)
