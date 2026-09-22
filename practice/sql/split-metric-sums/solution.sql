SELECT CASE WHEN metric_id < 5 THEN 'below_5'
          ELSE 'above_5' END AS label,
       SUM(metric_value)
FROM employee_metrics
GROUP BY 1
