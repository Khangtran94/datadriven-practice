SELECT e.err_id, e.err_type, e.message, e.svc_name, e.severity, e.count,e.first_at, status, latency, uptime
FROM err_tracks AS e
INNER JOIN svc_health
USING (svc_name)
