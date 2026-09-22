SELECT product_name,
      category, 
      price, 
       (SELECT AVG(price) FROM products) AS catalog_avg
FROM products
WHERE price > (SELECT AVG(price) FROM products)
ORDER BY price DESC
