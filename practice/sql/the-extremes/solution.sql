with top3 AS
(SELECT svc_name, 
  SUM(amount) AS total_amount
FROM cloud_costs
WHERE amount > 0
GROUP BY 1
order by 2),

rnk AS 
(SELECT *,
 ROW_NUMBER() OVER(ORDER BY total_amount) AS rn,
 ROW_NUMBER() OVER(ORDER BY total_amount DESC) AS rn_desc
FROM top3)

SELECT svc_name,
      total_amount
FROM rnk
WHERE rn <= 3 OR rn_desc <= 3
