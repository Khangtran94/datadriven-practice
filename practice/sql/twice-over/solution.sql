SELECT mdl_name, COUNT(*)
FROM ml_models
GROUP BY 1
HAVING COUNT(*) > 1
