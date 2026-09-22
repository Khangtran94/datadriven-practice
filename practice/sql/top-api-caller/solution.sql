SELECT user_id, COUNT(*) AS call_count
FROm api_calls
GROUP BY 1 
ORDER BY 2 DESC
LIMIT 1
