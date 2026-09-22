SELECT endpoint,
    MAX(latency) - MIN(latency) AS latency_diff,
    MAX(latency) / MIN(latency) AS latency_ratio,
    MAX(latency), MIN(latency)
FROm api_calls
WHERE latency > 0 
GROUP BY 1
