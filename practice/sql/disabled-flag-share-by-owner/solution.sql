SELECT owner, COALESCE(1.0 * SUM(CASE WHEN enabled = 0 THEN 1 END) / COUNT(*),0)
FROM feat_flags
GROUP BY 1
