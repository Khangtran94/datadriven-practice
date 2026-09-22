with avgteam AS
(SELECt team_name, amount,
      AVG(amount) OVER(PARTITION BY team_name) AS avg_amount,
      RANK() OVER(PARTITION BY team_name order by amount DESC) AS rnk
FROM cost_allocs)

SELECT team_name, amount
FROM avgteam
WHERE amount > avg_amount AND rnk > 3
