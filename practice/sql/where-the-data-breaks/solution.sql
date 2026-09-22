SELECT tbl_name, 
      COUNT(fail_pct) AS failing_checks,
      SUM(CASE WHEN LOWER(severity) IN ('high','critical') THEN 1 ELSE 0 END) AS high_severity_failures
FROM dq_checks
WHERE passed = 0
GROUP BY 1
-- ORDER BY 2 DESC
