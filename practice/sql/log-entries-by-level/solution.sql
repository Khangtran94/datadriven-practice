SELECT log_level, COUNT(*)
FROM server_logs
GROUP BY 1
ORDER By 1
