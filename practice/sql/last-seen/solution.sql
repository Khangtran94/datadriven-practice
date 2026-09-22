SELECT user_id, MAX(session_start)
FROM user_sessions
GROUP BY 1
