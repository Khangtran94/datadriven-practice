SELECT CONCAT(team_name, ' - ', svc_name) AS label,
      amount, region
FROM cost_allocs
WHERE amount between 500 and 1000
