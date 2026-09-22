SELECT
  CASE
    WHEN uptime >= 99.9 THEN 'Platinum'
    WHEN uptime >= 99 THEN 'Gold'
    WHEN uptime >= 95 THEN 'Silver'
    ELSE 'Bronze'
  END AS tier,
  MIN(latency) AS min_latency,
  AVG(latency) AS avg_latency,
  MAX(latency) AS max_latency
FROM svc_health
WHERE status NOT LIKE '%maintenance%'
GROUP BY tier
ORDER BY avg_latency DESC
