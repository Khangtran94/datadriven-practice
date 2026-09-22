with total AS
(SELECT svc_name, region, latency, 
      DENSE_RANK() OVER(PARTITION BY region ORDER BY latency DESC) AS max_latency,
      DENSE_RANK() OVER(PARTITION BY region ORDER BY latency) AS min_latency
FROM svc_health
WHERE region NOT LIKE '%test%' AND latency IS NOT NULL)

SELECT svc_name, 
      region, 
      latency,
      CASE WHEN max_latency = 1 THEN 'highest'
          WHEN min_latency = 1 THEN 'lowest' END AS latency_type
FROM total
WHERE max_latency = 1 OR min_latency = 1
ORDER BY region, latency_type
