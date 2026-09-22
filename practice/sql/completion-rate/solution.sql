select region, 
    ROUND(100.0 * SUM(CASE WHEN status = 'Completed' THEN 1 else 0 end) / COUNT(*),2) AS completion_pct
FROM orders
where region is not null
group by 1
