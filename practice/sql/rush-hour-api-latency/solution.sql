SELECT EXTRACT(hour from call_time), avg(latency)
FROM api_calls
WHERE EXTRACT(hour from call_time) BETWEEN 15 AND 17
GROUP BY 1      
