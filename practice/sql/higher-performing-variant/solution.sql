SELECT variant, AVG(value)
FROM ab_results
GROUP BY 1 
ORDER BY 2 DESC
LIMIT 1
