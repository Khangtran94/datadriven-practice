SELECT svc_name, 
      SUM(CASE WHEN severity = 'critical' THEN 1 ELSE 0 END) AS critical_count,
      SUM(CASE WHEN severity = 'warning' THEN 1 ELSE 0 END) AS warning_count,
      SUM(CASE WHEN severity = 'info' THEN 1 ELSE 0 END) AS info_count,
      SUM(CASE WHEN severity IS NULL THEN 1 ELSE 0 END) AS null_count,
      COUNT(*) AS total_count
FROM alert_events
GROUP BY 1
ORDER BY total_count DESC
