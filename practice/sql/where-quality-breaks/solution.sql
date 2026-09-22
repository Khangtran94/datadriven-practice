SELECT tbl_name, 
AVG(fail_pct) AS avg_fail_pct
FROM dq_checks
GROUP BY tbl_name
