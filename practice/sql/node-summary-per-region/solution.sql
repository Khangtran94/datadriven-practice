SELECT region, COUNT(*) AS total_nodes, COUNT(DISTINCT(node_type))
FROM infra_nodes
GROUP BY 1 
ORDER BY 2 DESC
