SELECT category, COUNT(*), AVG(rating), avg(price)
FROM products
GROUP BY 1
