SELECT department, COUNT(*) AS emp_count
FROM employees
GROUP BY 1 
QUALIFY DENSE_RANK() OVER(ORDER BY emp_count DESC) = 1
