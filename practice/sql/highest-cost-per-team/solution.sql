SELECT LOWER(team_name), MAX(amount)
FROM cost_allocs
GROUP BY 1 
ORDER BY 2 DESC
