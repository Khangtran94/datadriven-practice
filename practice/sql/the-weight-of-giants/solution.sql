SELECT provider, svc_name, SUM(amount) AS total_spend,
    DENSE_RANK() OVER(PARTITION BY provider ORDER BY SUM(amount) DESC) AS rnk
FROM cloud_costs
GROUP BY provider, svc_name
QUALIFY rnk <= 2
