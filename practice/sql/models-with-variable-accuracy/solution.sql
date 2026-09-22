SELECT mdl_name, 
      MIN(accuracy), MAX(accuracy)
FROM ml_models
WHERE accuracy IS NOT NULL
GROUP BY 1 
