SELECT *,
      SUM(metric_value) OVER(PARTITION BY department ORDER BY fiscal_year, fiscal_quarter) AS running_total
FROM employee_metrics
