SELECT p.product_id, 
      p.product_name, 
      COALESCE(SUM(p.price * t.quantity),0) AS total_revenue
FROM products AS p
LEFT JOIN transactions AS t
ON p.product_id = t.product_id
GROUP BY 1,2 
