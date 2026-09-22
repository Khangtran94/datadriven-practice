select category, min(price), max(price), max(price) - min(price) 
FROM products
WHERE price is not null
GROUP BY 1 
ORDER BY 4 desc
