SELECT team_name, region, SUM(amount)  AS total_amount,
      RANK() OVER(PARTITION BY region ORDER BY SUM(amount) DESC) AS rnk
FROM cost_allocs
WHERE amount is not null
GROUP BY 1, 2
