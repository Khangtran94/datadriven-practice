with total AS
(SELECT nspace, cpu_used/mem_used AS cpu_mem_ratio
FROm k8s_pods
WHERE status = 'Pending')

SELECT nspace, AVG(cpu_mem_ratio)
FROM total
GROUP BY 1 
ORDER BY 2 DESC
