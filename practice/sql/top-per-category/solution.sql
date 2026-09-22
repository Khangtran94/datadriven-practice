with rating_rank AS 
(SELECT product_name, category, rating,
    RANK() OVER(PARTITION BY category ORDER BY rating DESC) AS rnk_number
FROM products)

SELECT product_name, category, rating
FROM rating_rank
WHERE rnk_number = 1
