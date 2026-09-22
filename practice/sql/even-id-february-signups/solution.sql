SELECT *
FROM users
WHERE user_id % 2 = 0 AND extract(month from signup_date) = '02'
