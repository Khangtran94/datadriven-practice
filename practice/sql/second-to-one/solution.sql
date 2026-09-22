select distinct department, salary as second_highest_salary
FROM employees
qualify dense_rank() OVER(partition by department order by second_highest_salary desc) = 2
