SELECT region, 
    EXTRACT(month FROM transaction_date) AS txt_month, 
    SUM(profit) AS total_profit
FROM orders
INNER JOIN transactions 
ON orders.order_id % 100 = transactions.transaction_id % 100
WHERE extract(year from transaction_date) = 2026
    AND region IS NOT NULL
GROUP BY 1,2
ORDER BY 3 desc 
LIMIT 1
