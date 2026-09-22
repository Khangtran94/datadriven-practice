SELECT job_name, priority, rows_done
FROM batch_jobs
WHERE rows_done > 5000
ORDER BY 3 DESC
