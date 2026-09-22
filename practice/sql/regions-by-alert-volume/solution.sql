select region, COUNT(*)
FROM svc_health AS s
INNER JOIN alert_events AS a
USING (svc_name)
GROUP BY 1 
ORDER BY 2 desc
