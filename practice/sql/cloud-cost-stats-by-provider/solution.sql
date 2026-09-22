SELECT provider, 
      MIN(amount), MAX(amount), AVG(amount)
FROM (SELECT provider, amount FROM cloud_costs
      UNION ALL
      SELECT category AS provider, amount FROM cost_allocs) AS total
GROUP BY provider
