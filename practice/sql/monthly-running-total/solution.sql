SELECT product_id, 
      STRFTIME('%Y-%m',transaction_date) AS month,
      SUM(total_amount) AS monthly_total,
      SUM(SUM(total_amount)) OVER(PARTITION BY product_id ORDER BY STRFTIME('%Y-%m',transaction_date)) AS cumulative_total
FROM transactions
WHERE product_id IS NOT NULL
GROUP BY 1,2
