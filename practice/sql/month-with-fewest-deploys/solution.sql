SELECT EXTRACT(month from deploy_at), COUNT(*)
FROM deploy_logs
GROUP BY 1
ORDER BY 2
LIMIT 1
