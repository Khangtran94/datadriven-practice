SELECT endpoint,
      COUNT(*) AS total_calls, 
      ROUND(avg(latency),2) AS avg_latency,
      coalesce(SUM(CASE WHEN latency > 500 then 1 end),0) AS high_latency_count
FROM api_calls
GROUP BY 1 
HAVING COUNT(*) >= 5
ORDER BY 2 desc
