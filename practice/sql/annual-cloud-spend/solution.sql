SELECT strftime('%Y',bill_date) AS year, SUM(amount)
FROm cloud_costs
GROUP By 1 
ORDER BY 1
