SELECT svc_name, alert_id, severity, status, fired_at
FROm alert_events
WHERE resolved IS NULL
QUALIFY ROW_NUMBER() OVER(PARTITION BY svc_name ORDER BY fired_at) = 1
