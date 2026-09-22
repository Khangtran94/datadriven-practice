SELECT pod_name, nspace, 
      cpu_used, mem_used
FROM k8s_pods
QUALIFY DENSE_RANK() OVER(PARTITION BY nspace ORDER BY cpu_used) <= 5
