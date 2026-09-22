SELECT svc_name
FROM cloud_costs
GROUP BY svc_name
HAVING AVG(amount) > (SELECT AVG(amount) FROm cloud_costs)
