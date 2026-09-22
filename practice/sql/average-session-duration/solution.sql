SELECT user_id, AVG(session_duration_sec)
FROM user_sessions
WHERE session_duration_sec IS NOT NULL
GROUP BY 1
