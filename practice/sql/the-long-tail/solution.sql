with top5 AS
(SELECT upper(method) AS method, 
    latency, 
    ROW_NUMBER() OVER(PARTITION BY upper(method) ORDER BY latency) AS rnk
FROM api_calls
WHERE latency IS NOT NULL)

SELECT method,
    ROUND(AVG(latency),2) AS fastest_five_avg 
FROM top5
WHERE rnk <= 5
GROUP BY 1
