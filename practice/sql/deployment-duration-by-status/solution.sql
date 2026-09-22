SELECT svc_name, status, SUM(dur_secs)
FROM deploy_logs
GROUP BY 1,2 
ORDER BY 1
