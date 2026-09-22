SELECT avg(latency)
FROM api_calls
WHERE endpoint =  '/api/v1/search'
