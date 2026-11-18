SELECT username, COUNT(session_id) AS session_count
FROM users
INNER JOIN user_sessions 
USING (user_id)
GROUP BY 1
HAVING COUNT(session_id) >= 3
ORDER BY 2 desc
