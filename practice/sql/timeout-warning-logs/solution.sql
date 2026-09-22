











SELECT * 
FROM server_logs
WHERE message ILIKE '%timeout%' and log_level = 'WARN'
