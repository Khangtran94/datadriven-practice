SELECT COUNT(DISTINCT mdl_name)
FROM ml_models
WHERE status = 'training'
