SELECT pipe_name, SUM(rows_in - rows_out)
FROM data_pipes
WHERE lower(status) = 'success'
GROUP BY 1
ORDER BY 2 DESC
