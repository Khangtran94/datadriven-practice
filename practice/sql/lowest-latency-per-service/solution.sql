SELECT
  svc_name,
  MIN(latency) AS min_latency
FROM svc_health
WHERE region = 'us-east-1'
GROUP BY 1 
order by 2 desc
