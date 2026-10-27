SELECT e.emp_name, COALESCE(SUM(m.metric_value),0) AS total_metric_value
FROM employees AS e
LEFT JOIN employee_metrics AS m
ON e.department = m.department
GROUP BY e.emp_name, e.employee_id
