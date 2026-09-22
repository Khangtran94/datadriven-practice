SELECT pipe_name, start_at, ROUND(1.0 * rows_out / rows_in,4) AS throughput_ratio
FROM data_pipes
ORDER BY 1,start_at
