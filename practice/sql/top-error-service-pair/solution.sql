SELECT DISTINCT CONCAT(err_type,'-',svc_name) AS reporter_identity,
    COUNT(distinct e.err_id) AS distinct_errors
FROM err_tracks AS e
INNER JOIN alert_events
USING (svc_name) 
WHERE resolved is not null
GROUP BY 1
QUALIFY DENSE_RANK() OVER(ORDER BY distinct_errors DESC) = 1
ORDER BY 2 desc
