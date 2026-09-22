SELECT category, SUM(total_amount) AS total_revenue, SUM(quantity) AS total_units,
      DENSE_RANK() OVER(ORDER BY SUM(total_amount) DESC) AS position
FROM products
INNER JOIN transactions USING (product_id)
GROUP BY category
