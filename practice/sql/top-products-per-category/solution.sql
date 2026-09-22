with total AS
(SELECT category, product_name, SUM(total_amount) AS total_sales
FROM transactions AS t
INNER JOIN products AS p
ON t.product_id = p.product_id
GROUP BY 1,2)

SELECT * FROM total
QUALIFY ROW_NUMBER() OVER(PARTITION BY category ORDER BY total_sales DESC) <= 5
