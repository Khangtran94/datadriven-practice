SELECT region, avg(cpu_pct)
FROM infra_nodes
GROUP BY 1
