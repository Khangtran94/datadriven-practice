SELECT c.svc_name, 
      c.region,
      c.amount AS actual_cost,
      a.amount AS budget,
      CASE WHEN c.amount < a.amount THEN 'under'
          WHEN c.amount > a.amount THEN 'over'
          ELSE 'on_target' END AS budget_flag
FROM cloud_costs AS c
INNER JOIN cost_allocs AS a 
ON c.svc_name = a.svc_name AND c.region = a.region
