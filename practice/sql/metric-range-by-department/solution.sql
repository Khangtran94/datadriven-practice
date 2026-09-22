SELECT department, ROUND(AVG(metric_value),2), MIN(metric_value), MAX(metric_value)
FROM employee_metrics
GROUP BY 1 
ORDER BY 2 DESC
