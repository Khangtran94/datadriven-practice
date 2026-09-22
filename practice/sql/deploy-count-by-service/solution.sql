SELECT svc_name, COUNT(*) AS deploy_count
FROM deploy_logs
GROUP BY 1 
order by 2 desc
