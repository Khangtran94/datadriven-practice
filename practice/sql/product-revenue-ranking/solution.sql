SELECT p.product_name, 
      p.category,
      ROUND(SUM(t.total_amount),3) AS total_revenue
FROM products AS p 
INNER JOIN transactions AS t
ON p.product_id = t.product_id
GROUP BY 1,2 
ORDER BY 3 DESC
LIMIT 5
