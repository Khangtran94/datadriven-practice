SELECT p1.product_name AS product_1, 
      p2.product_name AS product_2,
      p1.category,
      p1.price AS price_1,
      p2.price AS price_2
FROM products AS p1
INNER JOIN products AS p2
USING (category)
WHERE p1.product_name != p2.product_name
    AND 2 * p1.price < p2.price
