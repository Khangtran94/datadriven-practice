SELECT user_id, COUNT(session_id) 
FROM  user_sessions INNER JOIN users USING (user_id)
GROUP BY 1 
HAVING COUNT(session_id) > 3
