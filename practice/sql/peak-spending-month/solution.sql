SELECT strftime('%Y-%m',bill_date), SUM(amount)
FROM cloud_costs
GROUP BY 1 order by 2 desc limit 1
