SELECT svc_name, 
      COUNT(*) FILTER(WHERE lower(env_name) = 'production') AS deploy_count,
      COUNT(*) FILTER(WHERE lower(status) = 'success') AS success_count,
      100 AS success_pct
FROM deploy_logs
GROUP BY 1 
HAVING deploy_count >= 3
