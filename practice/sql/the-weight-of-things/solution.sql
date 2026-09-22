with result AS
(SELECT region, svc_name, SUM(amount) AS total_amount
FROM cloud_costs
GROUP BY region, svc_name
ORDER BY region, total_amount DESC, svc_name),

rnk_order AS 
(SELECT *, ROW_NUMBER() OVER(PARTITION BY region ORDER BY total_amount DESC, svc_name) AS rnk
FROM result)

SELECT region, svc_name, total_amount FROM rnk_order WHERE rnk = 1
