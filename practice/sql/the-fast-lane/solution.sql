SELECT pipe_name, AVG(rows_out)
FROM data_pipes
WHERE dur_secs < 2700 
GROUP BY 1
ORDER BY 2 DESC
