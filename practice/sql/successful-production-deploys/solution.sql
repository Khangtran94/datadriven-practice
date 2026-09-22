SELECT *
FROM deploy_logs
WHERE status = 'success' AND dur_secs IS NOT NULL
ORDER BY dur_secs DESC
