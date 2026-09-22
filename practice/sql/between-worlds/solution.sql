with two AS
(SELECT user_id, COUNT(DISTINCT(os_name)) AS unique_os
FROM user_sessions
INNER JOIN devices 
USING (device_id)
GROUP BY user_id 
HAVING COUNT(DISTINCT(os_name)) >= 2)

SELECT user_id, os_name, device_type, session_start
FROM user_sessions
INNER JOIN devices
USING (device_id)
WHERE user_id IN (SELECT user_id FROM two)
