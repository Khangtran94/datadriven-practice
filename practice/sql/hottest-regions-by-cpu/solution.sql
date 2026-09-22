SELECT region, ROUND(AVG(cpu_pct),2)
FROM infra_nodes
GROUP BY 1 
ORDER BY 2 DESC
LIMIT 3
