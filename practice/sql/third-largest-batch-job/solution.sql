SELECT job_name, SUM(rows_done)
FROM batch_jobs
GROUP BY 1
order by 2 desc
LIMIT 1 OFFSET 2
