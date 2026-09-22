SELECT i1.node_id AS node_id_1,
      i2.node_id AS node_id_2,
      i1.region AS region
FROM infra_nodes AS i1
INNER JOIN infra_nodes AS i2
  ON i1.region = i2.region
    AND i1.node_id < i2.node_id
WHERE LOWER(i1.status) = 'running' AND LOWER(i2.status) = 'running'
ORDER BY i1.node_id, i2.node_id
