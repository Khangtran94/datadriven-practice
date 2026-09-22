SELECT node_id, hostname, cpu_pct
FROM infra_nodes
ORDER BY 3 DESC 
LIMIT 10
