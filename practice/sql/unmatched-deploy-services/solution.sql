SELECT distinct svc_name
FROM deploy_logs
WHERE svc_name not in (select distinct repo_name FROM ci_builds)
