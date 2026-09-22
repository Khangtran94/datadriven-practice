SELECT tbl_name, COUNT(*)
FROM dq_checks
WHERE passed = 0
GROUP BY 1 order by 2 desc
