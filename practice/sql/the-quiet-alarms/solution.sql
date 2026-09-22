SELECT COUNT(*) FROM dq_checks
WHERE LOWER(severity) = 'low' AND EXtrACT(year from run_at) = '2026'
