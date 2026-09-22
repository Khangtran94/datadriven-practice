with merged AS 
(SELECT product_name,   
        category, 
        total_amount
FROM products p
INNER JOIN transactions t ON p.product_id = t.product_id)

SELECT DISTINCT product_name,
      AVG(total_amount) OVER(PARTITION BY product_name) AS avg_amount,
      AVG(total_amount) OVER(PARTITION BY category) AS avg_cat_amount
FROM merged
QUALIFY avg_amount > avg_cat_amount
