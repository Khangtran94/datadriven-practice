SELECT category, product_name, price
FROM products
QUALIFY DENSE_RANK() OVER(PARTITION BY category ORDER BY price DESC) = 1
