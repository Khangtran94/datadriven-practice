SELECT region, SUM(profit)
FROM orders 
WHERE region IS NOT NULL AND region <> 'US'
GROUP BY 1 
oRDER BY 2 desc
LIMIT 3
