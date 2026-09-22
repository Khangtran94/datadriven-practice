SELECT username, COUNT(DISTINCT product_id) AS distinct_products, 
      SUM(total_amount) AS total_spend
FROM users INNER JOIN transactions USING (user_id)
GROUP BY user_id
HAVING COUNT(DISTINCT product_id) >= 2
ORDER BY 3 DESC
