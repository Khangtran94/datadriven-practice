SELECT category, COUNT(transaction_id) AS txt_count,
      DENSE_RANK() OVER(ORDER BY COUNT(transaction_id) DESC) AS rnk
FROM products
INNER JOIN transactions 
USING (product_id)
GROUP BY category
QUALIFY rnk <= 3
