SELECT category, AVG(price)
FROM products
GROUP BY category 
ORDER BY 2 
LIMIT 1
