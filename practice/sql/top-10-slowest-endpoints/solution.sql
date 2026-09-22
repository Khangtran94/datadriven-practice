SELECT endpoint, MAX(latency),
      DENSE_RANK() OVER(ORDER BY MAX(latency) DESC) AS rnk
FROM api_calls
WHERE EXTRACT(year from call_time) = 2026
GROUP BY 1
