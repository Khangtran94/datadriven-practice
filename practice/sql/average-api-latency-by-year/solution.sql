SELECT EXTRACT(year FROM call_time) AS year, 
      endpoint, AVG(latency)
FROM api_calls
GROUP BY 1,2 
ORDER BY 1,2 
