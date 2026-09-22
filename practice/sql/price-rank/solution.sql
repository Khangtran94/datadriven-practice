SELECT product_name, 
      category, 
      price,
      DENSE_RANK() OVER(PARTITION BY category ORDER BY price DESC) AS position
FROM products
WHERE price is not null
