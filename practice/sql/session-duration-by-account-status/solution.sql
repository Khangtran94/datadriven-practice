SELECT account_status,
      AVG(session_duration_sec) AS avg_session_duration
FROM users
INNER JOIN user_sessions
USING (user_id)
GROUP BY 1
