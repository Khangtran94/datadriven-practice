SELECT *
FROM server_logs
WHERE log_level = 'WARN'
    AND extract(hour from log_timestamp)  < 12
