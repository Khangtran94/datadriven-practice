with combine AS
(SELECT
    e1.metric_id AS metric_id_1,
    e1.metric_value AS metric_value_1,
    e2.metric_id AS metric_id_2,
    e2.metric_value AS metric_value_2
FROM employee_metrics AS e1
JOIN employee_metrics AS e2
    ON e1.metric_id <> e2.metric_id
   AND e1.metric_value < e2.metric_value
WHERE e1.metric_value IS NOT NULL
  AND e2.metric_value IS NOT NULL
ORDER BY metric_value_1)

SELECT metric_value_1, metric_value_2
FROM combine
WHERE metric_value_1 * metric_value_2 > 11
ORDER BY 1,2
