SELECT department, metric_name, MAX(metric_value)
FROM employee_metrics
GROUP BY 1,2
