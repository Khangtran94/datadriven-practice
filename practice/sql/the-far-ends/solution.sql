SELECT *
FROM employee_metrics
WHERE metric_name = 'headcount' AND (metric_value <= 10 OR metric_value >= 80)
