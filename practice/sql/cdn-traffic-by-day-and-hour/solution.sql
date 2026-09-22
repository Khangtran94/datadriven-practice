SELECT
    TO_CHAR(served_at, 'Day') AS weekday,
    EXTRACT(hour from served_at) AS hour,
    AVG(bytes * 0.95) AS avg_net_bytes
FROM cdn_logs
GROUP BY 1,2
ORDER BY extract(dow from served_at), 2
