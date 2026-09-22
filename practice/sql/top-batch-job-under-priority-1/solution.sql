select job_id, job_name, rows_done
FROM batch_jobs
WHERE priority = 1
QUALIFY DENSE_RANK() OVER(ORDER BY rows_done DESC) = 1
