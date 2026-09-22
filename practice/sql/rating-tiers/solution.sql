SELECT product_name, category, rating,
    dense_rank() OVER(partition by category order by rating desc) AS position
FROM products
WHERE rating is not null
