SELECT UPPER(provider), MIN(amount)
FROM cloud_costs
WHERE amount > 0 AND amount IS NOT NULL
GROUP BY 1 
