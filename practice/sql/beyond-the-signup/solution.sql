SELECT strftime('%Y-%m',session_start) AS month,
      COUNT(distinct user_id)  AS active_users,
      ROUND(AVG(session_duration_sec),3) AS avg_duration_sec
FROM user_sessions
INNER JOIN users USING (user_id)
WHERE month >= '2026-07'
GROUP BY 1 
ORDER BY 1
