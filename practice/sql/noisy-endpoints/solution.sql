SELECT endpoint, COUNT(*), AVG(latency)
FROM api_calls
WHERE status >= 400
GROUP BY 1 
HAVING COUNT(*) > 2
ORDER BY 2 DESC
