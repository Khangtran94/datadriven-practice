SELECT *, 
    SUM(rows_in) OVER(PARTITION BY status) AS status_total_rows_in
FROM data_pipes
