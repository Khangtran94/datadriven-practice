SELECT department,
    MAX(metric_value) - MIN(metric_value) AS volatility
FROM employee_metrics
GROUP BY department
ORDER BY volatility DESC
