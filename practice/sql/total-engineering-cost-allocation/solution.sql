SELECT SUM(amount)
FROM cost_allocs
WHERE lower(team_name) IN ( 'data-eng', 'backend', 'devops', 'platform')
