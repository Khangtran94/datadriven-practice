SELECT DISTINCT pod_name
FROM k8s_pods
WHERE mem_used BETWEEN 100 and 500
