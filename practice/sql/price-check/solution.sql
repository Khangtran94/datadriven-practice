SELECT category, AVG(price), COUNT(*) 
FROM products
WHERE price is not null
GROUP BY 1 
ORDER BY 2 DESC
