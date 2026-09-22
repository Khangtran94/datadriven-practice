SELECT product_name, rating
FROM products
WHERE rating in (SELECT MIN(rating) FROM products)
