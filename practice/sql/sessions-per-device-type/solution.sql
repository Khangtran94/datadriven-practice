select device_type, count(*)
FROM user_sessions
INNER JOIN devices 
USING (device_id)
GROUP By 1 
ORDER by 2 desc
