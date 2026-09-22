SELECT a1.latency AS latency_1,
      a2.latency AS latency_2,
      MAX(a1.latency, a2.latency) AS max_latency
FROM api_calls AS a1
CROSS JOIN api_calls AS a2
WHERE a1.latency IS NOT NULL AND a2.latency IS NOT NULL
ORDER BY a1.latency, a2.latency
LIMIT 100
