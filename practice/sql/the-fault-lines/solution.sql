SELECT account_status, 
     ROUND(1.0 * COUNT(event_type) FILTER(WHERE event_type IN ('error','timeout','crash')) / COUNT(event_type),3) AS negative_rate      
FROM users 
INNER JOIN event_data
USING (user_id)
GROUP BY 1
order by 2 desc
