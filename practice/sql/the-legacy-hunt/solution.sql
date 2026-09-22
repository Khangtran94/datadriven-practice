SELECT DISTINCT(pipe_name) FROM data_pipes
WHERE DATE(start_at) <= '2026-07-01'
