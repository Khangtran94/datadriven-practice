select category, product_name, 
      SUM(total_amount) AS product_revenue
FROM products
inner join transactions
USING (product_id)
GROUP BY 1,2
QUALIFY DENSE_RANK() OVER(PARTITION BY category ORDER BY product_revenue DESC) = 1
ORDER BY 3 desc
