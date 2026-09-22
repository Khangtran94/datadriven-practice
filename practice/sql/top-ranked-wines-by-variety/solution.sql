SELECT 197 AS user_id, 
      content_id, 
      duration_seconds
FROM content_items
WHERE duration_seconds <= (SELECT AVG(session_duration_sec) FROM user_sessions WHERE user_id = 197 GROUP BY user_id)
