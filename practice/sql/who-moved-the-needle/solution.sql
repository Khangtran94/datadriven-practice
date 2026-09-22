with total AS
(select 
    variant, user_id, SUM(value) as total_value
from ab_results
where test_name = 'onboarding_v3'
GROUP BY 1,2
order by 3 desc),

orders AS
(SELECT rank() OVER(ORDER BY total_value desc) AS rnk, *
FROM total)

SELECT * 
FROM orders
WHERE rnk <= 10
