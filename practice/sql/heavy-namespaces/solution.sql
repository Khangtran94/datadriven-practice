SELECT nspace, COUNT(*) 
FROM k8s_pods
GROUP BY nspace
HAVING COUNT(*) > 3
