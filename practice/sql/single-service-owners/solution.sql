SELECT DISTINCT svc_name, 1 AS service_count
FROM svc_health
-- GROUP BY svc_name
ORDER BY svc_name
LIMIT 10
