SELECT device_type, AVG(session_duration_sec)
FROM user_sessions
INNER JOIN devices USING (device_id)
GROUP BY 1
