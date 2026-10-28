SELECT product_name,
      category, 
      price, 
      CASE WHEN in_stock > 0 THEN 'In Stock' ELSE 'Out of Stock' END AS availability
FROM products
WHERE price IS NOT NULL
ORDER BY 1
