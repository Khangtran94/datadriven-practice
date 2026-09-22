SELECT department, fiscal_year, AVG(metric_value)
FROM employee_metrics
GROUP BY 1,2
ORDER BY 1,2
