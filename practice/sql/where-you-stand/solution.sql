SELECT svc_name,region,	latency, 
    AVG(latency) OVER (PARTITION BY region) AS avg_region_latency
FROM svc_health
