SELECT device_type,COUNT(DISTINCT user_id) AS user_count
FROM devices AS d
LEFT JOIN user_sessions AS u
USING (device_id)
GROUP BY 1
