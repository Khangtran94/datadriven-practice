with mth AS
(SELECT strftime('%Y-%m',bill_date) AS ym,
      SUM(amount) AS actual_cost
FROM cloud_costs
WHERE amount > 0
GROUP BY 1),

total AS
(SELECT ym, actual_cost, 
      LAG(actual_cost) OVER(ORDER BY ym) AS forecasted_cost
FROM mth)

SELECT *, ABS(ROUND(100 - (100.0 * forecasted_cost / actual_cost),3)) AS pct_error
FROM total
WHERE forecasted_cost IS NOT NULL
