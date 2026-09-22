SELECT category
FROM products
GROUP BY category 
HAVING SUM(in_stock) = 0
