SELECT trigger, 
      COUNT(*) AS total_builds,
      ROUND(1.0 * SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) / COUNT(*),3) AS success_rat
FROM ci_builds
GROUP BY trigger
