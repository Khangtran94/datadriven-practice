SELECT lower(team_name), amount
FROM cost_allocs
WHERE category = 'network'
ORDER BY 2 
LIMIT 1
