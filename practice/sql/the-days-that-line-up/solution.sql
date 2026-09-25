SELECT pipe_name,
      priority,
      MIN(dur_secs) AS min_duration,
      AVG(dur_secs) AS avg_duration,
      MAX(dur_secs) AS max_duration
FROM data_pipes
INNER JOIN batch_jobs
ON DATE(data_pipes.start_at) = DATE(batch_jobs.started)
WHERE DATE(batch_jobs.started) > '2026-01-01' AND LOWER(data_pipes.status) = 'success'
GROUP BY 1,2
