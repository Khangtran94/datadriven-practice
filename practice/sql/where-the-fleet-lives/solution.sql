SELECT region, COUNT(*)
FROM infra_nodes
WHERE region IN ('us-east-1', 'us-west-2', 'eu-west-1', 'eu-central-1')
GROUP BY 1 
ORDER BY 2 desc
