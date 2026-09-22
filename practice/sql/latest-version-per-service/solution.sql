SELECT svc_name, MAX(version)
FROM deploy_logs
GROUP BY 1
