SELECT region, AVG(uptime)
FROM svc_health
GROUP BY 1 order by 2 desc
