SELECT category, 
      SUM(total_amount) AS total
FROM products
INNER JOIN transactions 
USING (product_id)
WHERE strftime('%Y',transaction_date) = '2026'
GROUP BY 1 
QUALIFY total = MIN(total) OVER() OR total = MAX(total) OVER()
ORDER BY 2 desc
