SELECT user_id, username, SUM(total_amount) AS lifetime_spend
 FROM users
 INNER JOIN transactions 
 USING (user_id)
 GROUP BY 1,2 
 ORDER BY 3 DESC
 LIMIT 10
