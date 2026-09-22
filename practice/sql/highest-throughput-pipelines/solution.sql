SELECT pipe_name, MAX(rows_out)
FROM data_pipes
WHERE extract(year from start_at) = 2026
GROUP BY 1
order by 2 desc
