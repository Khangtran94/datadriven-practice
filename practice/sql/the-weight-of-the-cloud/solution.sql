SELECT DISTINCT CONCAT('Q',extract(quarter from bill_date)) AS quarter,
    SUM(cost_allocs.amount * cloud_costs.amount) AS weighted_spend
FROM cloud_costs
INNER JOIN cost_allocs
USING (svc_name)
WHERE extract(year from bill_date) = '2026'
GROUP BY 1
