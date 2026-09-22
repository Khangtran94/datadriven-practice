SELECT mdl_name, version, framework, status
FROM ml_models
WHERE mdl_name NOT IN (SELECT DISTINCT tbl_name FROM dq_checks)
ORDER BY train_at DESC
