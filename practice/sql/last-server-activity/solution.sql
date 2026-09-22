SELECT server_name, MAX(log_timestamp)
FROM server_logs
GROUP BY 1 
ORDER BY 2 DESC
