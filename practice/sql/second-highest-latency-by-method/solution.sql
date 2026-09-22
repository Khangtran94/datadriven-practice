with total AS
(select method AS method, endpoint, max(latency) as latency
FROM api_calls
GROUP BY 1,2)

SELECT method, endpoint, latency
FROM total
QUALIFY DENSE_RANK() OVER(PARTITION BY method order by latency desc) = 2
