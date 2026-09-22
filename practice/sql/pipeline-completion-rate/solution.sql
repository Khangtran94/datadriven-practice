SELECT pipe_name, AVG(100.0 * rows_out / rows_in)
FROM data_pipes
WHERE rows_in IS NOT NULL AND rows_in > 0
GROUP BY 1
