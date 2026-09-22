SELECT endpoint, AVG(latency) AS avg_latency,
      DENSE_RANK() OVER(ORDER BY AVG(latency)) AS rnk
FROM api_calls
GROUP BY endpoint
QUALIFY rnk <= 3
