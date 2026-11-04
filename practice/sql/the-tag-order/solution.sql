SELECT log_id, LOWER(env_name) AS env_name
FROM deploy_logs
WHERE lower(status) = 'failed'
