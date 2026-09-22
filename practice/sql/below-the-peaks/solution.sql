SELECT team_name, amount
FROM cost_allocs
QUALIFY amount > AVG(amount) OVER(PARTITION BY team_name)
    AND RANK() OVER(PARTITION BY team_name order by amount desc) > 5;
