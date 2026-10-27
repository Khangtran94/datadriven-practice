with mean AS
(SELECT region, ROUND(AVG(latency),3) AS avg_region_latency
FROM svc_health
GROUP BY 1)

SELECT svc_name, region, latency,
    avg_region_latency
FROM svc_health
INNER JOIN mean
USING (region)
ORDER BY region, svc_name, latency
