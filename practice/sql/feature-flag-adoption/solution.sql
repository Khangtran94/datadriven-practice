SELECT enabled, COUNT(*) AS flag_count
FROM feat_flags
GROUP BY enabled
ORDER BY 2 DESC
