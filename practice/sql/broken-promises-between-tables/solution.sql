SELECT COUNT(*)
FROM dq_checks
WHERE rule LIKE '%referential%' AND passed = 0
