SELECT server_name, 
    COUNT(*) AS match_count
FROM server_logs
WHERE message LIKE '%___-____%'
GROUP BY 1 order by 2 desc
limit 10
