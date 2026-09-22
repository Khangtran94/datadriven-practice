SELECT STRFTIME('%Y-%m',deploy_at) AS month, 
    COUNT(DISTINCT(CONCAT(svc_name, version))) 
FROM deploy_logs
GROUP BY 1
