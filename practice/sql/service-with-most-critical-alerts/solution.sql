SELECT *
FROM alert_events
WHERE svc_name = 'gateway'
ORDER BY fired_at
