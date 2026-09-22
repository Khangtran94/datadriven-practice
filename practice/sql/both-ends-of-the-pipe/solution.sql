SELECT DISTINCT author, COUNT(DISTINCT env_name) AS env_count
FROM deploy_logs
WHERE LOWER(env_name) IN ('dev','production') AND LOWER(status) = 'success'
GROUP BY author
