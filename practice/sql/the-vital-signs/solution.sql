SELECT status, COUNT(*) AS check_count
FROM svc_health 
WHERE svc_name = 'auth-svc'
GROUP BY 1
