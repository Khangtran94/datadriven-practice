with cost AS
(SELECT svc_name, SUM(amount) AS total_spend
FROM cloud_costs
WHERE strftime('%Y-%m',bill_date) ='2026-05'
GROUP BY svc_name
ORDER BY 2 DESC)

SELECT svc_name, total_spend, 
      NTILE(50) OVER(ORDER BY total_spend) AS bucket
FROM cost
QUALIFY bucket = 1
