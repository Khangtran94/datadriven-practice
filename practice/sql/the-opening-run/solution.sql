SELECT DISTINCT job_name, FIRST_VALUE(rows_done) OVER(PARTITION BY job_name ORDER BY started) 
FROM batch_jobs
