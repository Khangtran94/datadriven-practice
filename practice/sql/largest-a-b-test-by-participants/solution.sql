SELECT test_name, COUNT(DISTINCT user_id) 
FROM ab_results
GROUP BY 1 
ORDER BY 1 DESC
limiT 1
