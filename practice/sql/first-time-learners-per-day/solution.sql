with new AS
(SELECT user_id, MIN(DATE(session_start)) AS first_session_date
FROM user_sessions
GROUP BY user_id)

SELECT first_session_date, COUNT(*) AS new_user_count
FROM new
GROUP BY 1
ORDER BY 1
