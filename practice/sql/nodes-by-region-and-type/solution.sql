SELECT region, node_type, COUNT(*) AS node_count
FROM infra_nodes
GROUP BY 1, 2
