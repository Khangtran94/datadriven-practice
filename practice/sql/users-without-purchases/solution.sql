SELECT COUNT(user_id)
FROM users
WHERE user_id NOT IN (SELECT user_id FROM transactions)
