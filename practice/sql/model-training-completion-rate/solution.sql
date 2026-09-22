SELECT mdl_name,
      ROUND(AVG(accuracy),4) AS avg_accuracy,
      COALESCE(100.0 * SUM(CASE WHEN accuracy IS NOT NULL THEN 1 END) / COUNT(*),0) AS completion_rate
FROM ml_models
GROUP BY mdl_name
