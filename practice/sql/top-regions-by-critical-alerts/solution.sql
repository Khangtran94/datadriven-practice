SELECT region, COUNT(alert_id) AS critical_count
FROM svc_health
INNER JOIN alert_events
USING (svc_name)
WHERE lower(severity) = 'critical'
GROUP BY 1 
order by 2 desc
