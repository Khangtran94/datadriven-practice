with total AS
(select team_name, period, SUM(amount) AS monthly_cost
FROM cost_allocs
GROUP BY 1,2)

SELECT team_name, monthly_cost
FROM total
QUALIFY ROW_NUMBER() OVER(PARTITION BY team_name ORDER BY monthly_cost DESC) <= 3
