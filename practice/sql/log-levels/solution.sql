SELECT log_level, 
    COUNT(*),
    AVG(response_time_ms)
FROM server_logs
GROUP BY 1
HAVING COUNT(*) >= 5
ORDER BY 3 DESC
