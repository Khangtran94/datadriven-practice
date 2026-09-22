SELECT endpoint, latency, 
CASE WHEN latency < 100 THEN 'fast' WHEN latency <= 500 THEN 'normal' ELSE 'slow' END
FROM api_calls 
WHERE latency is not null
