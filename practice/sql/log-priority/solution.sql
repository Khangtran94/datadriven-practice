SELECT server_name, log_level, response_time_ms,
    CASE WHEN log_level IN ('CRITICAL','ERROR') THEN 'urgent'
        ELSE 'routine' END AS triage
FROM server_logs
WHERE response_time_ms IS NOT NULL
ORDER BY 4 DESC, 3 DESC
