SELECT svc_name, SUM(amount)
FROM cloud_costs
WHERE svc_name IN (SELECT distinct svc_name FROM cost_allocs)
GROUP BY 1 
order by 2 desc
LIMIT 2
