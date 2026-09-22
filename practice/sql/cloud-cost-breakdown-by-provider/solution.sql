select category, 
      SUBSTR(period, 1, 4) as yr,
      SUM(amount) as total_spend,
      COALESCE(SUM(CASE WHEN region = 'us-east-1' then amount ELSE 0 END),0) AS us_east_spend,
      COUNT(*) AS entry_count
FROM cost_allocs
WHERE SUBSTR(period, 1, 4) BETWEEN '2022' AND '2025'
GROUP BY category,2
order by 3 desc
