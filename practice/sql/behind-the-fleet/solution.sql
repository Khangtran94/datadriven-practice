SELECT server_name, 
      ROUND(AVG(response_time_ms),3) AS avg_response_ms
FROM server_logs
GROUP BY 1
HAVING ROUND(AVG(response_time_ms),3) > (SELECT AVG(response_time_ms) FROM server_logs)
order by 2 desc
