
SELECT
  department,
  emp_name,
  salary
FROM (
  SELECT
    department,
    emp_name,
    salary,
    DENSE_RANK() OVER (
      PARTITION BY department
      ORDER BY salary DESC
    ) AS rnk
  FROM employees
) AS ranked
WHERE rnk = 3
