with total AS
(SELECT strftime('%Y-%m',transaction_date) AS month,
      SUM(total_amount) AS monthly_revenue
FROM transactions
WHERE extract(year from transaction_date) = 2026
GROUP BY 1)

SELECT month, monthly_revenue,
      ROUND(AVG(monthly_revenue) OVER(ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS cumulative_avg
FROM total
