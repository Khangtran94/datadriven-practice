SELECT region, SUM(cpu_pct) AS total_cpu_pct
FROM infra_nodes
-- WHERE cpu_pct > 90
GROUP BY 1 order by 2 desc
