SELECT endpoint,COUNT(DISTINCT user_id)
FROM api_calls
GROUP BY 1 
HAVING COUNT(DISTINCT user_id) > 1
