SELECT department, MIN(metric_value), MAX(metric_value), AVG(metric_value),
      MAX(metric_value) - MIN(metric_value)
FROM employee_metrics
GROUP BY department
HAVING COUNT(*) > 5
ORDER BY 5 DESC
