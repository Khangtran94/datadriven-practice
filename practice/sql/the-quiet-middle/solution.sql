SELECT job_name, 
    DENSE_RANK() OVER(ORDER BY rows_done DESC) AS rnk
FROM batch_jobs
QUALIFY rnk BETWEEN 8 AND 10
