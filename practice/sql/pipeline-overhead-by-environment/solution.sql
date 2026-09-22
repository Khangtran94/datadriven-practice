with total AS
(SELECT LOWER(status) AS status,
      AVG(ABS(rows_in - rows_out)) AS avg_gap
FROM data_pipes
WHERE LOWER(status) IN ('success','running')
GROUP BY LOWER(status))

SELECT MAX(CASE WHEN status = 'running' THEN avg_gap END) 
    - MAX(CASE WHEN status = 'success' THEN avg_gap END) 
      AS overhead_difference
FROM total
