SELECT owner, COUNT(*) AS total_flags, 
      SUM(CASE WHEN enabled = 1 THEN 1 END) AS enabled_count,
       AVG(rollout)
FROM feat_flags
WHERE rollout is not null
GROUP BY 1
ORDER BY 3 DESc
