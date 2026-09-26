SELECT *
FROM users
WHERE strftime('%Y-%m',signup_date) = '2026-06'
    AND user_id % 2 = 0
ORDER BY user_id
