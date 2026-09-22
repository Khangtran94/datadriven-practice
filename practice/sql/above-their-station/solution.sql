SELECT e.emp_name AS employee_name, 
      e.salary AS employee_salary,
      m.emp_name AS manager_name,
      m.salary AS manager_salary,
      e.salary - m.salary AS salary_gap
FROM employees AS e
INNER JOIN employees AS m
ON e.manager_id = m.employee_id
where e.salary - m.salary > 0
order by salary_gap desc
