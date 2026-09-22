SELECT status, COUNT(*)
FROM batch_jobs
WHERE job_name LIKE '%export%'
GROUP BY 1 order by 2 desc
