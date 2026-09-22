SELECt os_name, AVG(session_duration_sec)
FROM user_sessions
INNER JOIN devices USING (device_id)
WHERE device_type = 'mobile'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 1
