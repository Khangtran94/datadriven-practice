SELECT device_type, AVG(session_duration_sec), MAX(session_duration_sec), COUNT(session_id)
FROM user_sessions
INNER JOIN devices 
USING (device_id)
GROUP BY 1 
HAVING COUNT(session_id) >= 5
ORDER BY 3 DESC
