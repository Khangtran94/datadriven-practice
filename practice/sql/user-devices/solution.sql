SELECT DISTINCT username,  device_type
FROM users
INNER JOIN user_sessions USING (user_id)
INNER JOIN devices USING (device_id)
