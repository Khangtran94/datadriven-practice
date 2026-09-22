SELECT department, MAX(metric_value)
FROM employee_metrics
GROUP BY 1 order by 2 desc
