with total AS
(SELECT CONCAT(EXTRACT(YEAR from call_time),'-Q',EXTRACT(QUARTER FROM call_time)) AS quarter,
      AVG(latency) AS avg_latency
FROM api_calls
WHERE EXTRACT(year from call_time) != '2026'
GROUP BY 1 
ORDER BY 1)

SELECT *, LAG(avg_latency) OVER(ORDER BY quarter) AS prev_avg_latency,
     avg_latency - LAG(avg_latency) OVER(ORDER BY quarter) AS qoq_change
FROM total
