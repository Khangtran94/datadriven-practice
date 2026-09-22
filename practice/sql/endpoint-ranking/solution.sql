WITH endpoint_stats AS (
  SELECT
    endpoint,
    COUNT(*) AS call_count,
    AVG(latency) AS avg_latency
  FROM api_calls
  GROUP BY endpoint
)
SELECT
  endpoint,
  call_count,
  avg_latency,
  RANK() OVER (
    ORDER BY avg_latency DESC
  ) AS position
FROM endpoint_stats
ORDER BY position, endpoint
