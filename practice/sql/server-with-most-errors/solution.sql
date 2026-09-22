SELECT server_name, COUNT(*)
FROM server_logs
WHERE log_level = 'ERROR'
GROUP BY 1 
ORDER BY 2 DESC 
LIMIT 1
