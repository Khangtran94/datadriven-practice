SELECT product_name, COUNT(transaction_id) AS order_count,
    DENSE_RANK() OVER(ORDER BY COUNT(transaction_id) DESC) AS rnk
FROM products inner join transactions USING (product_id)
GROUP BY 1 
QUALIFY rnk = 1
