
SELECT DISTINCT hostname, region, node_type
FROM infra_nodes
WHERE cpu_pct > 90 OR mem_pct > 85
