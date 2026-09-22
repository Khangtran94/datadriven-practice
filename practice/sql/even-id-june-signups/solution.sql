SELECT * 
FROM users
WHERE user_id % 2 = 0 AND EXTRACT(MONTH from signup_date) = '06'
