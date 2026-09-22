SELECT mdl_name, accuracy, framework
FROM ml_models
WHERE status = 'deployed'
ORDER BY 2 DESC
LIMIT 1
