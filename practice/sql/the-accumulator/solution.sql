SELECT bill_date, 
        SUM(amount) AS daily_spend, 
        SUM(SUM(amount)) OVER(ORDER BY bill_date) AS cumulative_spend
FROM cloud_costs
GROUP BY 1
