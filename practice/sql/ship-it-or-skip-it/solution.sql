SELECT date(deploy_at), COUNT(*)
FROM deploy_logs
GROUP BY 1
