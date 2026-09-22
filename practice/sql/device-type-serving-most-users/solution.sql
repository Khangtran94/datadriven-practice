SELECT device_type, COUNT(DISTINCT user_id) AS user_count
FROM user_sessions AS u 
INNER JOIN devices AS d USING (device_id)
GROUP BY 1 
QUALIFY DENSE_RANK() OVER(ORDER BY user_count DESC) = 1
