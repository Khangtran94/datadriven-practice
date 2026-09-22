select user_id, 
      MAX(session_duration_sec) FILTER(WHERE device_type = 'mobile') AS longest_mobile,
      MAX(session_duration_sec) FILTER(WHERE device_type = 'desktop') AS longest_desktop
FROM user_sessions
INNER JOIN devices 
USING (device_id)
WHERE extract(year from session_start) = 2025
GROUP BY 1
