SELECT product_name, price
FROM products
WHERE price > 200 AND category = 'Electronics' and in_stock = 1
ORDER BY price DESC
limit 5
