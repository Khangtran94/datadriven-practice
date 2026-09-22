SELECT user_id, 
      COUNT(*) AS total_session
FROM user_sessions
GROUP BY user_id
HAVING COUNT(*) > (SELECT COUNT(*) / COUNT(DISTINCT user_id) FROM user_sessions)
