SELECT EXTRACT(MONTH from start_at) AS month, 
COUNT(*) AS pipeline_runs
FROM data_pipes
GROUP BY 1 
ORDER BY 2 dESC limit 1
