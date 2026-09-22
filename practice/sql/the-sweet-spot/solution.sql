SELECT product_name, price
FROM products
WHERE category = 'Electronics'
    AND rating >= 4.0 AND in_stock = 1
ORDER BY 2 
LIMIT 1
