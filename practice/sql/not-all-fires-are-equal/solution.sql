with total AS
(SELECT svc_name, severity, COUNT(*) AS cnt
FROM alert_events
WHERE svc_name IN (SELECT distinct svc_name from svc_health)
  AND extract(year from fired_at) = 2026
GROUP BY 1,2
HAVING COUNT(*) > 1)

SELECT severity, ROUND(AVG(cnt),1)
FROM total
GROUP BY 1
