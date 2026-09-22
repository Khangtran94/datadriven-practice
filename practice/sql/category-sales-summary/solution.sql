SELECT category, 
      COUNT(transaction_id) AS transactions_count, 
      SUM(total_amount) AS total_revenue
FROM transactions AS t
INNER JOIN products AS p
ON t.product_id = p.product_id
WHERE EXTRACT(year from transaction_date) = 2026
GROUP BY category
ORDER BY 3 DESC
