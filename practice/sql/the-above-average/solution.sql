with total AS
(SELECT category, 
        AVG(price) AS avg_price
FROM products
GROUP BY category)

SELECT product_name, 
      category, 
      price, 
      avg_price
FROM products 
INNER JOIN total
USING (category)
WHERE price > avg_price
