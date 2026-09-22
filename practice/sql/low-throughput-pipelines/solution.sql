SELECT pipe_name, rows_out
FROM data_pipes
WHERE rows_out < 2000
ORDER BY 2 DESC
