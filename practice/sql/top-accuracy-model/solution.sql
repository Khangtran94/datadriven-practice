SELECT mdl_name, MAX(accuracy),
      DENSE_RANK() OVER(ORDER BY MAX(accuracy) DESC) AS rnk
FROM ml_models
GROUP BY 1
QUALIFY rnk = 1
