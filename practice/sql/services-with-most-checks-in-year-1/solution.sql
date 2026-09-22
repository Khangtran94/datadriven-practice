with each AS
(SELECT svc_name, extract(year from checked) AS year, 
COUNT(*) AS check_count
FROM svc_health
GROUP BY 1, 2
ORDER BY 1, 2 desc),

compare AS
(SELECT *,
    DENSE_RANK() OVER(PARTITION BY svc_name ORDER BY check_count DESC) AS rnk
FROM each)

SELECT svc_name, check_count
FROM compare 
WHERE year = 2026 AND rnk = 1
ORDER BY check_count DESC
