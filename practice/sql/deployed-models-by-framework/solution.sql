SELECT framework, COUNT(*)
FROM ml_models
WHERE status = 'deployed'
GROUP BY 1 
