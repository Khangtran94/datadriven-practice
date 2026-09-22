SELECT region, node_type, AVG(cpu_pct), AVG(mem_pct)
FROm infra_nodes
GROUP BY 1,2 
