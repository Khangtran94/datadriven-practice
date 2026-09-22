SELECT DISTINCT exp_name
FROM experiments
WHERE variant IN ('variant_a','variant_b')
GROUP BY 1 
HAVING COUNT(DISTINCT variant) = 2
