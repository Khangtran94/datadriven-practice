with min_max AS
(SELECT user_id,
      MIN(signup_date) AS first_person, 
      MAX(signup_date) AS last_person
FROM users
WHERE user_id IN (SELECT DISTINCT user_id FROM user_sessions)
GROUP BY user_id),

top2 AS
(SELECT user_id
FROM min_max
WHERE first_person = (SELECT MIN(first_person) FROM min_max)
   OR last_person = (SELECT MAX(last_person) FROM min_max))

SELECT *
FROM user_sessions
WHERE user_id IN (SELECT user_id FROM top2)
ORDER BY user_id
