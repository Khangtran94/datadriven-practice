SELECT *
FROM employee_metrics
WHERE CAST(metric_value AS INT) + CAST(SUBSTRING(fiscal_quarter,2) AS INT) = 5
ORDER BY metric_id








--
