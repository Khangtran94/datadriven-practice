SELECT region
FROM infra_nodes
WHERE node_type IN (
  'compute',
  'storage',
  'network',
  'gpu'
  )
GROUP BY 1
HAVING COUNT(DISTINCT hostname) > 2
