SELECT username, COUNT(session_id)
FROM users AS u
INNER JOIN user_sessions as us
USING (user_id)
GROUP BY u.user_id, username
HAVING COUNT(session_id) >= 5
