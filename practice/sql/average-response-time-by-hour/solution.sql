SELECT extract(hour from log_timestamp), AVG(response_time_ms)
FROm server_logs
GROUP BY 1 
