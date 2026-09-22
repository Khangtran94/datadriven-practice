SELECT alloc_id, 
        category, 
        amount, 
        ROUND(amount / (SUM(amount) OVER(PARTITION BY category)),3) AS pct_of_category
FROM cost_allocs
WHERE category IN ('compute','storage','network')
ORDER BY category, alloc_id
