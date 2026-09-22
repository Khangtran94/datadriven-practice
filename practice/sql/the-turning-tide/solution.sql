SELECT provider, 
    SUM(amount) FILTER(WHERE EXTRACT(year from bill_date) = 2026 AND EXTRACT(month from bill_date) BETWEEN 7 and 12) -
    SUM(amount) FILTER(WHERE EXTRACT(year from bill_date) = 2026 AND EXTRACT(month from bill_date) BETWEEN 1 and 6) AS spend_difference    
FROM cloud_costs
GROUP BY provider
ORDER BY 2 desc
