SELECT device_type, COUNT(*)
FROM user_sessions
INNER JOIN devices USING (device_id)
GROUP BY 1 
order by 2 desc limit 1
