SELECT endpoint, latency
FROM api_calls
WHERE endpoint ILIKE '%auth%'
