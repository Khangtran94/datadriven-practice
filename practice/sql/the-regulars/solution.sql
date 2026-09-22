SELECT user_id
FROM user_sessions
GROUP BY 1
HAVING COUNT(DISTINCT(STRFTIME('%Y-%m',session_start))) >= 3
