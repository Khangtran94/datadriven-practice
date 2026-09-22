SELECT user_id, AVG(session_duration_sec) AS avg_duration 
FROM user_sessions
GROUP BY 1 
HAVING AVG(session_duration_sec) < 1000
