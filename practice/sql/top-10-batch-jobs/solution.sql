SELECT job_name,
  DENSE_RANK() OVER(ORDER BY SUM(rows_done) DESC) AS rank
FROM batch_jobs
GROUP BY job_name
LIMIT 10
