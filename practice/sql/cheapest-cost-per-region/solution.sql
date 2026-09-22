SELECT region, min(amount)
FROM cloud_costs
GROUP BY 1 
