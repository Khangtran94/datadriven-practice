SELECT date(started) AS job_date, 
        job_name,
        rows_done
FROM batch_jobs
WHERE rows_done is not null
QUALIFY DENSE_RANK() OVER(PARTITION BY job_date ORDER BY rows_done DESC) = 1
ORDER BY job_date
