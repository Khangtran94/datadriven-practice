with total AS
(SELECT strftime('%Y-%m',transaction_date) AS month, 
        SUM(total_amount) AS revenue
FROM transactions
GROUP BY 1)

SELECT *,
    ROUND(100.0 * (revenue - LAG(revenue) OVER(ORDER BY month)) / LAG(revenue) OVER(ORDER BY month),2) AS pct_change
FROM total
