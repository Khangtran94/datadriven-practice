SELECT
  PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY null_pct) - 1.5 AS median_null_pct
FROM ml_features
WHERE dtype ILIKE 'float%' AND null_pct IS NOT NULL
