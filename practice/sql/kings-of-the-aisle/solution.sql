with total AS
(SELECT category, 
    product_name, 
    SUM(total_amount) AS total_revenue
FROM products
INNER JOIN transactions
USING (product_id)
WHERE extract(year FROM transaction_date) = 2026
GROUP BY 1,2)

SELECT category, product_name, total_revenue
FROM total
QUALIFY RANK() OVER(PARTITION BY category ORDER BY total_revenue DESC, product_name) = 1
ORDER BY total_revenue desc
