with deploy AS
(SELECT svc_name, 
        COUNT(log_id) AS deploy_count
FROM deploy_logs
GROUP BY 1),

alert AS
(SELECT svc_name, COUNT(alert_id) AS alert_count
FROM alert_events GROUP BY 1)

SELECT svc_name, deploy_count, coalesce(alert_count,0)
FROM deploy 
LEFT JOIN alert
USING (svc_name)
