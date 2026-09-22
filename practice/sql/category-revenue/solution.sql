SELECT category,
      SUM(total_amount),
      COUNT(transaction_id),
      SUM(total_amount) / COUNT(transaction_id)
FROM transactions INNER JOIN products USING (product_id)
GROUP BY 1
HAVING SUM(total_amount) > 500
ORDER BY 2 DESC
