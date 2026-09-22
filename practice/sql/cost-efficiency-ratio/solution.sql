SELECT svc_name, 10.0* SUM(amount) / (SELECT COUNT(*) FROM cloud_costs)
FROM cloud_costs
WHERE svc_name = 'EC2'
