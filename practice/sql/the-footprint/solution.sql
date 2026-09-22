select region, count(*)
FROm infra_nodes
GROUP BY 1 order by 2 desc
