SELECT tbl_name, 
      COUNT(*) AS failing_checks, 
      SUM(CASE WHEN LOWER(severity) IN ('high','critical') THEN 1 ELSE 0 END) AS high_severity_failures
FROM dq_checks
WHERE passed = false
GROUP BY 1
ORDER BY 2 desc, 1
