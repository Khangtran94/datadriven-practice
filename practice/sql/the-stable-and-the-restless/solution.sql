SELECT status, COUNT(*) 
FROM k8s_pods
WHERE restarts = 0
GROUP BY 1 
ORDER BY 2 DESC
