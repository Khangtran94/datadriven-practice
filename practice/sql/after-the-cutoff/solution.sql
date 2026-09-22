SELECT COUNT(*) AS deploy_count,
      MAX(dur_secs) AS max_duration
FROM deploy_logs
WHERE CAST(EXTRACT(MONTH FROM deploy_at) AS INTEGER) >= 4 
    AND env_name = 'production'
