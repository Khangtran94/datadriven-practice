SELECT endpoint, MAX(latency)
FROM api_calls
GROUP BY 1
ORDER BY 2 DESC
LIMIT 3
