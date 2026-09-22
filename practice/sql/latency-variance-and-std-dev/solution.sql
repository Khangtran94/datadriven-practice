SELECT
    AVG(latency) AS mean_latency,
    AVG(latency * latency)
        - POWER(AVG(latency), 2) AS variance_latency,
    SQRT(
        AVG(latency * latency)
        - POWER(AVG(latency), 2)
    ) AS stddev_latency
FROM api_calls
WHERE status = 200
  AND latency > 0;
