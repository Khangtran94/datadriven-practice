SELECT user_id, username, MIN(total_amount) As min_amount
FROM users
INNER JOIn transactions 
USING (user_id)
GROUP BY 1,2
ORDER BY 3 
