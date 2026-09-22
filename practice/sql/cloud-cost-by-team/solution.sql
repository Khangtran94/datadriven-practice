SELECT team_name, SUM(amount) AS total_cost
FROM cost_allocs
GROUP By 1 
ORDER By 2 DESC
