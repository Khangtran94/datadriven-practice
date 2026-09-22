with total AS
(SELECT username, COUNT(transaction_id) AS num
FROM users INNER JOIN transactions USING (user_id)
GROUP BY user_id, username)

SELECT username, DENSE_RANK() OVER(ORDER BY num DESC) AS rnk
FROM total
QUALIFY rnk = 1
