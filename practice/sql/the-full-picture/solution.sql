with payroll AS
(SELECT department,
      SUM(salary) AS total_payroll
FROM employees
GROUP BY 1),

q1 AS
(SELECT department,
      SUM(metric_value) AS q1_metric_total
FROM employee_metrics
WHERE fiscal_quarter = 'Q1'
GROUP BY 1)

SELECT p.department, 
      p.total_payroll,
      COALESCE(q1_metric_total,0) AS q1_metric_total
FROM payroll AS p
LEFT JOIN q1 
USING (department)
