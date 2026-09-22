SELECT category, MAX(price) AS max_price
FROM products
GROUP By category
ORDER BY 2 DESC
LIMIT 3
