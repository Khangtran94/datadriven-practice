SELECT DISTINCT region
FROm orders
WHERE region NOT IN (SELECT distinct country FROM customers)
