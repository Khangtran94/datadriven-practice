SELECT d.svc_name,
      d.version,
      d.env_name,
      d.status
FROM deploy_logs AS d
LEFT JOIN alert_events AS e
ON d.svc_name = e.svc_name
WHERE alert_id IS NULL
ORDER BY d.deploy_at DESC
