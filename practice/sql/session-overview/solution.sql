SELECT username, 
      COALESCE(count(s.session_id),0),
      MAX(s.session_duration_sec)
FROM users 
LEFT JOIN user_sessions AS s
USING (user_id)
GROUP BY 1
