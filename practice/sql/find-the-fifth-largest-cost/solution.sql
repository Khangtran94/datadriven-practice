SELECT *
FROM cloud_costs
QUALIFY DENSE_RANK() OVER(ORDER BY amount desc) = 5
