SELECT
  user_id,
  product_id,
  SUM(total_amount) AS total_revenue
FROM transactions
GROUP BY user_id, product_id
HAVING MIN(quantity) >= 2
ORDER BY user_id, total_revenue DESC
