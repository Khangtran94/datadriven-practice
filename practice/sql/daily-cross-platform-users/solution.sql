SELECT DATE(session_start), COUNT(DISTINCT user_id)
FROM user_sessions
INNER JOIN devices USING (device_id)
WHERE device_type IN ('mobile','web')
GROUP BY 1 
ORDER BY 1
