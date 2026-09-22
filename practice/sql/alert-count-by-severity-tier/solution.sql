SELECT severity, COUNT(*) 
FROM alert_events
GROUP BY 1 
ORDER By 2 DESC
