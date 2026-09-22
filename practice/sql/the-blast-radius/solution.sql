SELECT LOWER(author) AS author, ROUND(AVG(latency),2) AS avg_score
FROm deploy_logs AS d
INNER JOIN svc_health AS s
ON d.svc_name = s.svc_name
GROUP BY 1
ORDER By 2 DESC
