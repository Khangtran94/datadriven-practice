SELECT user_id, username
FROM users
WHERE user_id NOT IN (SELECT user_id FROM user_sessions)
