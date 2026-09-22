with total AS
(SELECT svc_name, COUNT(*) AS occurrence_count 
FROM alert_events
GROUP BY svc_name)

SELECT *, DENSE_RANK() OVER(ORDER BY occurrence_count DESC) AS rnk
FROM total
