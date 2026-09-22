SELECT endpoint, MAX(latency)
FROM api_calls
WHERE extract(month from call_time) = 3
GROUP BY 1 order by 2 desc
