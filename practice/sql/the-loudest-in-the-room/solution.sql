SELECT client, SUM(blocked)
FROM rate_limits
GROUP BY client 
ORDER BY 2 DESC
LIMIT 2
