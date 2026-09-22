SELECT category, product_name, SUM(quantity) AS total_quantity,
    DENSE_RANK() OVER(PARTITION BY category ORDER BY SUM(quantity) DESC, product_name) AS rank
FROM transactions 
INNER JOIN products USING (product_id)
GROUP BY 1,2
QUALIFY rank < 3
