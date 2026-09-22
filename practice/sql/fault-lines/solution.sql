SELECT DATE(event_timestamp) AS event_day,
      age_bucket AS region,
      COUNT(event_type) FILTER (WHERE event_type IN ('error','crash')) / COUNT(event_type) FILTER (WHERE event_type = 'open') AS error_rate
FROM event_data 
INNER JOIN users 
USING (user_id)
WHERE event_type IN ('open','error','crash')
GROUP BY 1,2
