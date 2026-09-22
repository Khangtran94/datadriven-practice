with area AS
(SELECT region, sum(amount)
FROM cloud_costs
GROUP BY 1 
ORDER BY 2 desc
limit 1)

SELECT * 
FROM cost_allocs
WHERE region = (select region from area)
