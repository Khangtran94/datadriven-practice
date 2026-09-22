SELECT category, product_name, 
    SUM(total_amount) AS total_revenue
FROM products
INNER JOIN transactions 
USING (product_id)
where extract(year from transaction_date) = 2026
GROUP BY 1,2 
QUALIFY DENSE_RANK() OVER(PARTITION BY category ORDER BY total_revenue DESC) = 1
order by 3 desc
