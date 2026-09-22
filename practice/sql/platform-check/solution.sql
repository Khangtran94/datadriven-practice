SELECT user_id, device_type, os_name, session_duration_sec
FROM user_sessions
INNER JOIN devices uSING (device_id)
WHERE session_duration_sec > 1000
