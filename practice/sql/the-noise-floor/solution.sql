SELECT svc_name,
    ROUND(100.0 * SUM(CASE WHEN LOWER(severity) IN ('critical','high') THEN 1 ELSE 0 END) / COUNT(*),1) AS high_urgency_pct
FROM alert_events
GROUP BY svc_name
QUALIFY high_urgency_pct > 50
ORDER BY 2 DESC
