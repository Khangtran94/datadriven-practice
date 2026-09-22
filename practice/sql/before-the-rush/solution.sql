SELECT category, 
    STRFTIME('%Y-%m',transaction_date) AS month,
    SUM(total_amount)
FROM transactions
INNER JOIN products
USING (product_id)
GROUP BY 1,2
ORDER BY 1,2 
