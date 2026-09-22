with speed AS
(SELECT server_name, 
      AVG(response_time_ms) AS avg_time
FROM server_logs
GROUP BY server_name
ORDER BY avg_time DESC),

level AS
(SELECT *, ROW_NUMBER() OVER(ORDER BY avg_time) AS rnk
FROM speed)

SELECT avg_time - (SELECT avg_time FROM level WHERE rnk = 10) AS latency_gap
FROM level
WHERE server_name = 'web-prod-01'
