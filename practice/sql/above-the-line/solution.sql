with total AS
(SELECT strftime('%Y-%m',bill_date) AS month,
        svc_name, SUM(amount) AS spend,
        CASE WHEN SUM(amount) > 100 THEN 1 ELSE 0 END AS over_100
FROM cloud_costs
GROUP BY 1,2)

SELECT month,
      ROUND(100.0 * SUM(over_100) / COUNT(*),3) AS pct_hitting_threshold
FROM total 
GROUP BY month
