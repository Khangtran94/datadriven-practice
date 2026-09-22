SELECT u.user_id, username, SUM(session_duration_sec)
FROM users AS u
INNER JOIN user_sessions AS s ON u.user_id = s.user_id
GROUP BY 1,2
ORDER BY 3 DESC LIMIT 10
