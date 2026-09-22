SELECT category, 
      COUNT(DISTINCT user_id) AS unique_buyers,
      SUM(total_amount)
FROM products 
INNER JOIN transactions USING (product_id)
GROUP BY category
HAVING COUNT(transaction_id) >= 3
ORDER BY 3 DESC
