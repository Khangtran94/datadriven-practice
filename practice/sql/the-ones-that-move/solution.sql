WITH product_revenue AS (
  SELECT
    p.category,
    p.product_name,
    SUM(oi.quantity * oi.unit_price) AS revenue
  FROM order_items AS oi
  INNER JOIN products AS p
    ON p.product_id = oi.product_id
  GROUP BY p.category, p.product_name
  ORDER BY 1,3 desc)
  
SELECT *, rank() OVER(PARTITION BY category order by revenue desc) AS revenue_rank 
FROM product_revenue
QUALIFY revenue_rank <= 3
