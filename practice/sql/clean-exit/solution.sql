SELECT job_id
FROM batch_jobs
WHERE priority = 1 and status ilike 'completed'
