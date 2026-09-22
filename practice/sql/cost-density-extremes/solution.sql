select region, provider,
      ROUND(SUM(amount) / COUNT(distinct svc_name)) AS cost_density
FROM cloud_costs
where amount is not null
GROUP by 1,2
QUALIFY cost_density = MAX(cost_density) OVER()
      OR cost_density = MIN(cost_density) OVER()
