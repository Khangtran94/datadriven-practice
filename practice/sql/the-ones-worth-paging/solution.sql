SELECT log_level, COUNT(*) AS total_count
FROM server_logs
WHERE log_level IN ('CRITICAL','ERROR','WARN')
GROUP BY log_level
