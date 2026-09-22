SELECT svc_name
FROM svc_health
WHERE lower(status) = 'healthy' AND extract(year from checked) = 2026
GROUP BY svc_name
HAVING COUNT(DISTINCT EXTRACT(quarter from checked)) > 1
