SELECT svc_name,
      COUNT(*) AS total_alerts,
      SUM(CASE WHEN LOWER(severity) = 'critical' THEN 1 ELSE 0 END) AS critical_count,
      SUM(CASE WHEN LOWER(severity) = 'high' THEN 1 ELSE 0 END) AS high_count,
      SUM(CASE WHEN ack_by IS NULL THEN 1 ELSE 0 END) AS unacked_count,
      COUNT(*) / COUNT(DISTINCT status) AS avg_per_status
FROM alert_events
GROUP BY svc_name
ORDER BY total_alerts DESC
