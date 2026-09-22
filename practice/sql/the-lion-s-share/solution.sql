SELECT category, 
      SUM(total_amount) AS total_revenue,
      COUNT(transactions.transaction_id) AS transaction_count,
      ROUND(100.0 * SUM(total_amount) / SUM(SUM(transactions.total_amount)) OVER (),2) AS revenue_share_pct
FROM products
INNER JOIN transactions
USING (product_id)
GROUP BY category
ORDER BY total_revenue DESC
