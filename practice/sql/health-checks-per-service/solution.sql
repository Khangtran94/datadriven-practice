SELECT svc_name, COUNT(*) AS check_count
FROM svc_health
GROUP BY 1
