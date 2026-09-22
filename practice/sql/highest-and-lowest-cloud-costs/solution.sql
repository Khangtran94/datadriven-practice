with total AS
(SELECT cost_id, amount, svc_name,
  DENSE_RANK() OVER(ORDER BY amount) AS lowest,
  DENSE_RANK() OVER(ORDER BY amount DESC) AS highest
FROM cloud_costs
WHERE amount IS NOT NULL)

SELECT cost_id, amount, svc_name, 
      CASE WHEN lowest = 1 THEN 'Lowest Cost'
          WHEN highest = 1 THEN 'Highest Cost' END AS cost_type
FROM total
WHERE lowest = 1 OR highest = 1;
