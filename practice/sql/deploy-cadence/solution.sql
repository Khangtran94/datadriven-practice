select env_name, COUNT(*) as deploy_count,
     ROUND(AVG(dur_secs),3) AS avg_duration, 
     COUNT(DISTINCT svc_name) AS unique_services
FROM deploy_logs
GROUP BY 1 
order by 2 desc
