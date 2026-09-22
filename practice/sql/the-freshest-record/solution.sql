SELECT *
FROM server_logs
WHERE datetime(log_timestamp) >= (
    SELECT datetime(MAX(log_timestamp), '-7 days')
    FROM server_logs
)
ORDER BY datetime(log_timestamp) DESC;
