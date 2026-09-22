with top1 AS
(SELECT *, DENSE_RANK() OVER(PARTITION BY department ORDER BY metric_value DESC) AS rnk
FROM employee_metrics
QUALIFY rnk = 1)

SELECT DISTINCT department, metric_name, metric_value, rnk
FROM top1
