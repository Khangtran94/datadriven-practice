SELECT m1.metric_value AS val1, 
      m2.metric_value AS val2,
      m3.metric_value AS val3
FROM employee_metrics AS m1
CROSS JOIN employee_metrics AS m2
CROSS JOIN employee_metrics As m3
WHERE m1.metric_id < m2.metric_id  AND m2.metric_id < m3.metric_id
      AND m1.metric_value + m2.metric_value + m3.metric_value = 25
