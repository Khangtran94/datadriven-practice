SELECT avg(cpu_pct)
FROM infra_nodes
WHERE node_type = 'gpu'
