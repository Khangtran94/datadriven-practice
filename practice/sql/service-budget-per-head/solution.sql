with each AS
(SELECT svc_name,     
      COUNT(DISTINCT lower(team_name)) AS head,
      SUM(amount) AS total_budget
FROM cost_allocs 
GROUP BY 1)

SELECT svc_name, ROUND(total_budget * 20 / head) AS budget_per_head
FROM each
WHERE svc_name IN (SELECT DISTINCT svc_name FROM cloud_costs)
