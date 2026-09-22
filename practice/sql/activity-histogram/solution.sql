with calculate AS 
(SELECT user_id, COUNT(*) AS session_count
FROM user_sessions
GROUP BY user_id)

SELECT session_count, COUNT(*) AS number_users
FROM calculate
GROUP BY session_count
ORDER BY 1 
