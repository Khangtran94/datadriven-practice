SELECT u.user_id, COALESCE(COUNT(DISTINCT event_type),0) AS event_type_count
FROM users AS u 
LEFT JOIN event_data AS e
USING (user_id)
GROUP BY 1
