with top2 AS
(SELECT distinct nspace, pod_name, cpu_used,
      DENSE_RANK() OVER(PARTITION BY nspace ORDER BY cpu_used DESC) AS rnk
FROM k8s_pods
QUALIFY rnk <= 2)

SELECT
    nspace,
    MAX(CASE WHEN rnk = 1 THEN pod_name END) AS highest_cpu_pod,
    MAX(CASE WHEN rnk = 2 THEN pod_name END) AS second_highest_cpu_pod
FROM top2
GROUP BY nspace;
