with total AS
(SELECT job_name, rows_done, DENSE_RANK() OVER(ORDER BY rows_done DESC) AS rnk
FROM batch_jobs
QUALIFY DENSE_RANK() OVER(ORDER BY rows_done DESC) BETWEEN 8 AND 10)

SELECT job_name, rnk
FROM total
