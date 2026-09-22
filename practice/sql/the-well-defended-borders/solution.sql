SELECT region, COUNT(*)
FROM infra_nodes
WHERE LOWER(status) = 'running'
GROUP BY 1 
HAVING COUNT(*) >= 5 
