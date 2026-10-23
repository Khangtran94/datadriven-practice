SELECT lower(trim(svc_name)) as svc_name, lower(trim(status)) AS status,
    SUM(dur_secs) AS total_duration
FROM deploy_logs
GROUP BY 1,2
order by 1,2
