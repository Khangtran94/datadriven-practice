SELECT COUNT(*)
FROM batch_jobs
WHERE status = 'running' and extract(year from started) = 2025 and ended is null
