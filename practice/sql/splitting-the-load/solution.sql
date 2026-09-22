SELECT team_name, 
      CONCAT(svc_name, ' - ',region) AS entry_label,
      amount
FROM cost_allocs
QUALIFY ROW_NUMBER() OVER(PARTITION BY team_name order by amount desc) <= 3
ORDER BY team_name, amount DESC

    
