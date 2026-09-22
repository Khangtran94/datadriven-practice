SELECT department, COUNT(*) AS employee_count
FROM employees
GROUP BY department
ORDER BY 2 DESC, 1
