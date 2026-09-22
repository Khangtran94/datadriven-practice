SELECT
  product_id,
  SUM(total_amount) AS total_sales
FROM transactions
WHERE DATE(transaction_date) >= DATE(
  '2026-12-28',
  '-30 days'
  )
GROUP BY product_id
ORDER BY total_sales DESC, product_id
LIMIT 3
