with divide AS
(SELECT endpoint, latency, 
      NTILE(4) OVER(PARTITION BY endpoint ORDER BY latency) AS bucket
from api_calls
WHERE latency IS NOT NULL)

SELECT endpoint, bucket, MIN(latency) AS min_latency, 
      MAX(latency) AS max_latency, 
      AVG(latency) AS avg_latency
FROM divide
GROUP BY 1,2
