with total AS
(SELECT svc_name, COUNT(*) AS occurrence_count
FROM alert_events
GROUP BY 1)

SELECT svc_name,occurrence_count, DENSE_RANK() OVER(ORDER BY occurrence_count DESC) AS rnk
FROM total
