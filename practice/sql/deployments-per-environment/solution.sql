SELECT env_name, COUNT(*) 
FROM deploy_logs
GROUP BY 1
