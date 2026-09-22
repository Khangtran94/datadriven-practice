SELECT ABS(
    MAX(CASE WHEN department = 'Engineering' THEN metric_value END) -
    MAX(CASE WHEN department = 'Marketing' THEN metric_value END)
) AS abs_difference
FROM employee_metrics
WHERE department IN ('Engineering', 'Marketing');
