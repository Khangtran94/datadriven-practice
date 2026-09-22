SELECT SUM(rows_done) AS total_rows
FROM (SELECT rows_done, DENSE_RANK() OVER(ORDER BY rows_done) AS rnk FROM batch_jobs)
WHERE rnk <= 100
