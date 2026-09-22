SELECT repo_name, 
      SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS success_count,
      SUM(CASE WHEN status = 'failed' THEN 1 ELSE 0 END) AS failed_count,
      COUNT(*) AS total_builds,
      ROUND(100.0 * SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) / COUNT(*),3) AS success_rate
FROM ci_builds
GROUP BY repo_name
ORDER BY success_rate DESC
