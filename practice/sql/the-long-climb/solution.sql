SELECT user_id, product_id, total_amount, transaction_date,
    SUM(total_amount) OVER(PARTITION BY user_id ORDER BY transaction_date) AS cumulative_sales
FROM transactions
ORDER BY 1,4
