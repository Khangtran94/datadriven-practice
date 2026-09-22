with total AS
(SELECT user_id, DATE(session_start) AS first_session_date,
      ROW_NUMBER() OVER(PARTITION BY user_id ORDER BY session_start) AS rnk
FROM user_sessions
QUALIFY rnk = 1)

SELECT first_session_date, COUNT(user_id) AS new_user_count
FROM total
GROUP BY 1
ORDER BY 1
