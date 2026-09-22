SELECT nspace, pod_name, MIN(mem_used) AS mem_used
FROM k8s_pods
WHERE mem_used IS NOT NULL
GROUP BY 1,2
ORDER BY 3 
LIMIT 5
