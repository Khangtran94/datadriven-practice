SELECT e.emp_name AS employee, 
      e.salary AS emp_salary,
      m.emp_name AS manager,
      m.salary AS mgr_salary
FROM employees AS e
INNER JOIN employees AS m
ON e.manager_id = m.employee_id
WHERE e.salary > m.salary
