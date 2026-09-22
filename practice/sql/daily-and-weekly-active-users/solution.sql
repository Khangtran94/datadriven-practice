SELECT CAST(session_start AS DATE) AS day,
      COUNT(DISTINCT user_id) AS dau
FROM user_sessions
GROUP BY 1
ORDER BY 1
