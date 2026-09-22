with new AS
(SELECT user_id, username, email, signup_date,
       DENSE_RANK() OVER(PARTITION BY user_id ORDER BY signup_date DESC) AS rnk
FROM users
WHERE user_id IS NOT NULL)

SELECT user_id, username, email, signup_date
FROM new 
WHERE rnk = 1
ORDER BY user_id
