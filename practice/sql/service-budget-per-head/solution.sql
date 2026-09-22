SELECT ca.svc_name, 
    ROUND(SUM(ca.amount) / COUNT(DISTINCT ca.team_name)) AS budget_per_head
FROM cost_allocs AS ca
INNER JOIN cloud_costs AS cc
USING (svc_name)
GROUP BY 1 
ORDER BY 2 desc
