SELECT extract(year from start_at), COUNT(*)
FROM data_pipes
WHERE LOWER(status) = 'failed'
AND pipe_name = 'etl_users'
AND start_at IS NOT NULL
group by 1
