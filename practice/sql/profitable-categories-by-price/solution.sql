select category, MIN(price), avg(rating)
FROM products
GROUP BY 1 order by 2
