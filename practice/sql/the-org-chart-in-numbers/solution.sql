SELECT department,
    COALESCE(SUM(CASE WHEN fiscal_quarter = 'Q1' THEN 1 ELSE 0 END),0) AS q1,
    COALESCE(SUM(CASE WHEN fiscal_quarter = 'Q2' THEN 1 ELSE 0 END),0) AS q2,
    COALESCE(SUM(CASE WHEN fiscal_quarter = 'Q3' THEN 1 ELSE 0 END),0) AS q3,
    COALESCE(SUM(CASE WHEN fiscal_quarter = 'Q4' THEN 1 ELSE 0 END),0) AS q4
FROM employee_metrics
GROUP BY department
