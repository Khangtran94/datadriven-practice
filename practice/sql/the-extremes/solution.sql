with total AS
(SELECT svc_name, SUM(amount) AS total_amount
FROM cloud_costs
WHERE extract(year from bill_date) = 2025
GROUP BY svc_name)

SELECT svc_name, total_amount
FROM total
QUALIFY
    ROW_NUMBER() OVER (ORDER BY total_amount) <= 5
    OR ROW_NUMBER() OVER (ORDER BY total_amount DESC) <= 5
ORDER BY total_amount
