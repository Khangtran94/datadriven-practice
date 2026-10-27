SELECT pipe_name, MIN(start_at), MAX(start_at), COUNT(*)
FROM data_pipes
GROUP BY 1
