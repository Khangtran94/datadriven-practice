SELECT endpoint, COUNT(DISTINCT user_id)
FROM api_calls
WHERE strftime('%Y-%m',call_time) = '2026-06'
GROUP BY 1 
