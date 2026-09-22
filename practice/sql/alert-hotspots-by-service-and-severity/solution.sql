SELECT svc_name, severity, COUNT(*) AS alert_count
FROM alert_events
GROUP BY 1,2 
ORDER BY 2,3 DESC
