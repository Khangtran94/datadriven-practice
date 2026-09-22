SELECT strftime('%Y-%m',session_start) AS month,
      COUNT(DISTINCT(user_id)) AS unique_visitors
FROM user_sessions
GROUP BY month
HAVING COUNT(DISTINCT(user_id)) > 2
