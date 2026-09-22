SELECT product_name, 
      SUM(total_amount) AS total_total_amount,
      ROW_NUMBER() OVER(ORDER BY SUM(total_amount) DESC) AS rnk
FROM transactions 
INNER JOIN products
USING (product_id)
GROUP BY product_name, product_id
QUALIFY rnk <= 10
