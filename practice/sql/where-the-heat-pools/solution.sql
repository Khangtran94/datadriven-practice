SELECT region, AVG(cpu_used)
FROM infra_nodes As i
INNER JOIN k8s_pods As k
oN i.node_id = k.pod_id
GROUP BY 1
