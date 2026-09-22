select severity,
      SUM(CASE WHEN resolved IS NOT NULL THEN 1 ELSE 0 END) AS resolved_count,
      SUM(CASE WHEN resolved IS NULL THEN 1 ELSE 0 END) AS unresolved_count
FROM alert_events
GROUP BY 1
