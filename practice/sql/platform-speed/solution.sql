SELECT device_type,
     ROUND(AVG(session_duration_sec),3) AS avg_duration,
     MAX(session_duration_sec) AS max_duration,
     COUNT(session_id) AS session_count
FROM devices
INNER JOIN user_sessions
USING (device_id)
GROUP BY 1
HAVING COUNT(session_id) >= 35
