SELECT COUNT(*) AS low_severity_count
FROM dq_checks
WHERE severity = 'low' AND extract(year from run_at) = 2026
