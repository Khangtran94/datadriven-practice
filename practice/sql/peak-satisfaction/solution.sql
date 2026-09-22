SELECT department, MAX(metric_value), MIN(metric_value), COUNT(*)
FROM employee_metrics
WHERE metric_name = 'satisfaction_score'
GROUP by 1
