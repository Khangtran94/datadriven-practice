with total AS
(SELECT LOWER(svc_name) AS svc_name, 
      deploy_at, 
      LAG(deploy_at) OVER(PARTITION BY LOWER(svc_name) ORDER BY deploy_at) AS previous,
      JULIANDAY(deploy_at) - JULIANDAY(LAG(deploy_at) OVER(PARTITION BY LOWER(svc_name) ORDER BY deploy_at)) AS day_diff
FROM deploy_logs
ORDER BY svc_name, deploy_at)

SELECT svc_name, ROUND(AVG(day_diff),3) AS average_day_gap
FROM total 
WHERE day_diff IS NOT NULL
GROUP BY svc_name
ORDER BY average_day_gap DESC;
