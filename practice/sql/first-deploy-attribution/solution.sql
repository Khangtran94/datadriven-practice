select svc_name, count(*) AS total_deploys, 1 as first_time_deploys
FROM deploy_logs
group by 1 
