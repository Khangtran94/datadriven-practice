SELECT device_type, COUNT(*)
FROM user_sessions
INNER JOIN devices USING (device_id)
WHERE device_type = 'mobile'
GROUP by 1
